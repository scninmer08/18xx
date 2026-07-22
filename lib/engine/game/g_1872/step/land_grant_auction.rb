# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1872
      module Step
        class LandGrantAuction < Engine::Step::Base
          ACTIONS = %w[choose].freeze
          Bid = Struct.new(:entity, :price, keyword_init: true)

          attr_reader :bids

          def setup
            @bids = Hash.new { |hash, key| hash[key] = [] }
            @auctioned_ipo_row_indices = []
            @cycled_ipo_rows = false
            @pending_assignments = Hash.new { |hash, key| hash[key] = [] }
          end

          def description
            return 'Assign Land Grants' if assigning_land_grants?

            'Place Land Grant Bid Marker'
          end

          def pass_description
            'Pass'
          end

          def available
            singleton_land_grants
          end

          def show_companies
            true
          end

          def show_map
            true
          end

          def hide_corporations?
            true
          end

          def visible?
            true
          end

          def players_visible?
            true
          end

          def auctioning; end

          def auctioning_company; end

          def auctioneer?
            true
          end

          def bidding_tokens(player)
            [@game.class::LAND_GRANT_BID_MARKERS - @game.retained_land_grant_bid_marker_count(player), 0].max
          end

          def may_purchase?(_company)
            false
          end

          def may_choose?(company)
            !assigning_land_grants? && can_place_marker?(current_entity, company)
          end

          def may_bid?(_company)
            false
          end

          def min_increment
            10
          end

          def min_bid(company)
            bid_value_for_marker(company)
          end

          def max_bid(entity, company)
            return 0 unless company

            [entity.cash - committed_cash(entity), 0].max
          end

          def max_place_bid(entity, company)
            max_bid(entity, company)
          end

          def choice_available?(entity)
            assigning_land_grants? && same_entity?(entity, current_entity)
          end

          def committed_cash(player, _show_hidden = false)
            active_markers(player).sum { |_company, bid| bid.price }
          end

          def choices_for_ipo_row(entity, company, _ipo_row_number)
            return [] if assigning_land_grants?
            return [] unless can_place_marker?(entity, company)

            [[company.id, bid_choice_name(company)]]
          end

          def actions(entity)
            if assigning_land_grants?
              return [] unless same_entity?(entity, current_entity)
              return [] unless @pending_assignments[entity].any?

              return ACTIONS
            end

            return [] unless same_entity?(entity, current_entity)
            return [] if exposed_land_grants.empty?
            return [] unless president_of_any_floated_corporation?(entity)
            return [] unless bid_marker_available?(entity)
            return [] if choices.empty?

            ACTIONS + ['pass']
          end

          def choice_name
            return "Assign #{current_assignment.name}" if assigning_land_grants?

            'Choose a land grant to bid on'
          end

          def choices
            return assignment_choices if assigning_land_grants?

            exposed_land_grants
              .select { |company| can_place_marker?(current_entity, company) }
              .to_h { |company| [company.id, bid_choice_name(company)] }
          end

          def process_choose(action)
            return assign_land_grant(action) if assigning_land_grants?

            company = exposed_land_grants.find { |grant| grant.id == action.choice }
            raise GameError, 'That land grant is not exposed' unless company
            raise GameError, "#{action.entity.name} cannot place a bid marker on #{company.name}" unless
              can_place_marker?(action.entity, company)

            move_marker(action.entity, company)
            reset_passes!
            @round.next_entity!
          end

          def auto_actions(entity)
            return [] unless entity == current_entity
            return [] if assigning_land_grants?
            return [] if president_of_any_floated_corporation?(entity) && bid_marker_available?(entity) && choices.any?

            [Engine::Action::Pass.new(entity)]
          end

          def process_pass(action)
            @log << "#{action.entity.name} passes"
            action.entity.pass!
            advance_after_pass!
          end

          def skip!
            return pass! if assigning_land_grants?

            if automatic_pass?(current_entity)
              @log << "#{current_entity.name} auto-passes"
              current_entity.pass!
              return finish_auction_round! if entities.all?(&:passed?) || exposed_land_grants.empty?

              return pass!
            end

            super
          end

          private

          def automatic_pass?(entity)
            return false unless entity
            return false unless same_entity?(entity, current_entity)
            return true if exposed_land_grants.empty?
            return true unless president_of_any_floated_corporation?(entity)
            return true unless bid_marker_available?(entity)

            choices.empty?
          end

          def assigning_land_grants?
            @pending_assignments.any? { |_player, grants| grants.any? }
          end

          def current_assignment
            @pending_assignments[current_entity]&.first
          end

          def assignment_choices
            grant = current_assignment
            return {} unless grant

            eligible_assignment_corporations(current_entity, grant).to_h do |corporation|
              ["#{grant.id}|#{corporation.id}", "#{grant.name} to #{corporation.name}"]
            end
          end

          def assign_land_grant(action)
            grant_id, corporation_id = action.choice.split('|', 2)
            grant = @pending_assignments[action.entity].find { |company| company.id == grant_id }
            corporation = eligible_assignment_corporations(action.entity, grant).find do |candidate|
              candidate.id == corporation_id
            end
            raise GameError, 'That land grant assignment is not available' if !grant || !corporation

            assign_grant_to_corporation!(grant, action.entity, corporation)
            @pending_assignments[action.entity].delete(grant)
            if @pending_assignments[action.entity].empty?
              @pending_assignments.delete(action.entity)
              action.entity.pass!
            end
            finish_assignment_round! unless assigning_land_grants?
            @round.next_entity! if assigning_land_grants?
          end

          def exposed_land_grants
            @game.land_grant_ipo_rows.filter_map(&:first)
          end

          def singleton_land_grants
            @game.land_grant_ipo_rows.select { |row| row.size == 1 }.filter_map(&:first)
          end

          def bid_choice_name(company)
            "Place marker on #{company.name} (#{@game.format_currency(bid_value_for_marker(company))})"
          end

          def active_markers(entity)
            @bids.filter_map do |company, bids|
              bid = bids.last
              [company, bid] if bid && same_entity?(bid.entity, entity)
            end
          end

          def active_marker_count(entity)
            active_markers(entity).size
          end

          def bid_marker_count(entity)
            active_marker_count(entity) + @game.retained_land_grant_bid_marker_count(entity)
          end

          def bid_marker_available?(entity)
            bid_marker_count(entity) < @game.class::LAND_GRANT_BID_MARKERS
          end

          def president_of_any_floated_corporation?(entity)
            presidential_floated_corporations(entity).any?
          end

          def presidential_floated_corporations(entity)
            @game.all_corporations.select do |corporation|
              !corporation.closed? && corporation.floated? && corporation.president?(entity)
            end
          end

          def can_place_marker?(entity, company)
            return false unless entity == current_entity
            return false unless president_of_any_floated_corporation?(entity)
            return false unless marker_bid_display_available?(entity, company)
            return false if territory_unavailable_to_player?(entity, company)
            return false unless bid_marker_available?(entity)

            value = bid_value_for_marker(company)
            value <= max_bid(entity, company)
          end

          def marker_bid_display_available?(entity, company)
            return false unless entity
            return false unless exposed_land_grants.include?(company)
            return false if @bids[company].last && same_entity?(@bids[company].last.entity, entity)

            true
          end

          def territory_unavailable_to_player?(entity, company)
            !grant_commitments_assignable?(entity, active_markers(entity).map(&:first) + [company])
          end

          def grant_commitments_assignable?(entity, grants, used_territories_by_root = Hash.new { |h, k| h[k] = [] })
            return true if grants.empty?

            grant = grants.first
            territory = @game.land_grant_territory(grant)
            presidential_floated_corporations(entity).any? do |corporation|
              root = @game.shell_root[corporation] || corporation
              next false if territory && used_territories_by_root[root].include?(territory)
              next false unless @game.genealogy_land_grant_territory_available?(corporation, grant)

              next_used = Hash.new { |hash, key| hash[key] = [] }
              used_territories_by_root.each { |used_root, territories| next_used[used_root] = territories.dup }
              next_used[root] << territory if territory
              grant_commitments_assignable?(entity, grants.drop(1), next_used)
            end
          end

          def bid_value_for_marker(company)
            previous_bid = @bids[company].last
            previous_bid ? previous_bid.price + min_increment : min_increment
          end

          def move_marker(entity, company)
            bid_value = bid_value_for_marker(company)
            displaced_entity = @bids[company].last&.entity
            remove_marker(displaced_entity, company) if displaced_entity && !same_entity?(displaced_entity, entity)
            @bids[company] << Bid.new(entity: entity, price: bid_value)

            @log << "#{entity.name} places bid marker on #{log_name(company)} (#{@game.format_currency(bid_value)})"
          end

          def log_name(company)
            company.name.sub(/ \([A-Z]\d+\)\z/, '')
          end

          def remove_marker(entity, company)
            @bids[company].reject! { |bid| same_entity?(bid.entity, entity) }
          end

          def same_entity?(a, b)
            return true if a.equal?(b)
            return false if !a || !b
            return a.id == b.id if a.respond_to?(:id) && b.respond_to?(:id)

            false
          end

          def same_company?(a, b)
            return true if a.equal?(b)
            return false if !a || !b
            return a.id == b.id if a.respond_to?(:id) && b.respond_to?(:id)

            false
          end

          def reset_passes!
            entities.each(&:unpass!)
          end

          def advance_after_pass!
            if entities.all?(&:passed?) || exposed_land_grants.empty?
              finish_auction_round!
              return true
            end

            @round.next_entity!
            false
          end

          def finish_auction_round!
            award_land_grants!
            prepare_land_grant_assignments!
            unless @cycled_ipo_rows
              @game.cycle_unauctioned_land_grant_rows(@auctioned_ipo_row_indices)
              @cycled_ipo_rows = true
            end

            if assigning_land_grants?
              entities.each(&:pass!)
              @pending_assignments.each_key(&:unpass!)
              @round.goto_entity!(next_assignment_player)
            else
              pass!
            end
          end

          def award_land_grants!
            @bids.each do |company, bids|
              winning_bid = bids.last
              next unless winning_bid

              winner = winning_bid.entity
              bid_value = winning_bid.price
              raise GameError, "#{winner.name} cannot afford #{@game.format_currency(bid_value)} for #{company.name}" if
                winner.cash < bid_value

              winner.spend(bid_value, @game.bank)
              company.value = 0
              @log << "#{winner.name} pays #{@game.format_currency(bid_value)} to the bank for #{company.name}"

              company.owner = winner
              winner.companies << company unless winner.companies.include?(company)
              auctioned_ipo_row_index = @game.land_grant_ipo_rows.index { |row| row.first == company }
              @auctioned_ipo_row_indices << auctioned_ipo_row_index if auctioned_ipo_row_index
              @auctioned_ipo_row_indices.uniq!
              @game.remove_land_grant(company)
              @log << "#{winner.name} receives #{company.name} with a land grant value of "\
                      "#{@game.format_currency(company.value)}"
              @pending_assignments[winner] << company
            end

            @bids.clear
          end

          def prepare_land_grant_assignments!
            @pending_assignments.keys.each do |player|
              corporations = presidential_floated_corporations(player)
              next unless corporations.one?

              corporation = corporations.first
              next unless @pending_assignments[player].all? do |grant|
                @game.genealogy_land_grant_territory_available?(corporation, grant)
              end

              @pending_assignments[player].dup.each do |grant|
                assign_grant_to_corporation!(grant, player, corporation)
              end
              @pending_assignments.delete(player)
            end
          end

          def eligible_assignment_corporations(player, grant)
            return [] unless grant

            presidential_floated_corporations(player).select do |corporation|
              @game.genealogy_land_grant_territory_available?(corporation, grant)
            end
          end

          def assign_grant_to_corporation!(grant, player, corporation)
            player.companies.delete(grant)
            @game.assign_land_grant_bid_marker!(grant, player)
            corporation.companies << grant unless corporation.companies.include?(grant)
            grant.owner = corporation
            @log << "#{player.name} assigns #{grant.name} to #{corporation.name}"
            grant.name = land_grant_name_with_value(grant)
          end

          def land_grant_name_with_value(grant)
            base_name = grant.name.sub(/ – \$-?\d+\z/, '')
            "#{base_name} – #{@game.format_currency(grant.value)}"
          end

          def next_assignment_player
            entities.find { |entity| @pending_assignments[entity].any? }
          end

          def finish_assignment_round!
            entities.each(&:pass!)
            pass!
          end
        end
      end
    end
  end
end
