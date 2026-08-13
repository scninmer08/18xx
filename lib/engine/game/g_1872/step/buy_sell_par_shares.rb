# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'

module Engine
  module Game
    module G1872
      module Step
        class BuySellParShares < Engine::Step::BuySellParShares
          ACTION_START_BRANCH = 'start_branch'

          def setup
            super
            @branch_stage = nil
            @branch_sponsor = nil
            @branch_corporation = nil
            @selected_land_grant = nil
            clear_branch_start_cache!
          end

          def actions(entity)
            if starting_branch?
              return [] unless entity == current_entity

              case @branch_stage
              when :land_grant_upgrade
                return ['lay_tile']
              when :par
                return ['par']
              when :shares
                return branch_share_purchase_actions(entity)
              end
            end

            actions = super
            if entity == current_entity && !must_sell?(entity) && !bought? && branch_start_available?(entity)
              actions << 'choose'
              actions << 'pass' unless actions.include?('pass')
            end

            actions.uniq
          end

          def choice_name
            case @branch_stage
            when :land_grant_upgrade
              "Lay an upgrade on #{@selected_land_grant.name} for #{@branch_corporation.name}'s home station"
            else
              'Choose a corporation to start a branch railroad'
            end
          end

          def choices
            branch_start_choices(current_entity)
          end

          def choice_available?(_entity)
            false
          end

          def render_choices?
            true
          end

          def process_choose(action)
            return start_branch_from_land_grant_choice(action.choice) unless starting_branch?
          end

          def process_par(action)
            if @branch_stage == :par
              process_branch_par(action)
              return
            end

            super.tap { clear_branch_start_cache! }
          end

          def process_buy_shares(action)
            if @branch_stage == :shares
              process_branch_buy_shares(action)
              return
            end

            super.tap { clear_branch_start_cache! }
          end

          def process_lay_tile(action)
            raise GameError, 'No land grant home upgrade is pending' unless @branch_stage == :land_grant_upgrade
            raise GameError, 'That hex is not the selected land grant' unless action.hex == selected_land_grant_hex
            raise GameError, 'That tile cannot be used for this land grant home' unless
              potential_tiles(action.entity, action.hex).any? { |tile| tile.name == action.tile.name }

            @game.lay_land_grant_home_upgrade!(action.hex, action.tile, action.rotation)
            place_land_grant_home_and_continue_to_par!
          end

          def process_pass(action)
            if @branch_stage == :shares
              finish_branch_share_buying!
              return
            end

            super
          end

          def auto_actions(entity)
            return [Engine::Action::Pass.new(entity)] if
              @branch_stage == :shares && entity == current_entity && !branch_share_buy_available?

            super
          end

          def visible_corporations
            return [@branch_sponsor, @branch_corporation].compact if starting_branch?

            @game.sorted_corporations.reject do |corporation|
              corporation.type == :branch && !corporation.ipoed
            end
          end

          def show_other
            return @branch_corporation if starting_branch? && @branch_corporation&.ipoed

            nil
          end

          def selected_corporation
            return @branch_corporation if @branch_stage == :par

            nil
          end

          def show_map
            true
          end

          def ipo_type(_corporation)
            :par
          end

          def par_price_only(corporation, _share_price)
            @branch_stage == :par && corporation == @branch_corporation
          end

          def allow_president_change?(corporation)
            !@game.sponsored_corporation?(corporation)
          end

          def can_buy?(entity, bundle)
            return can_buy_branch_share?(entity, bundle) if @branch_stage == :shares

            if entity&.corporation?
              return false unless bundle&.owner == @game.share_pool
              return false unless bundle.corporation.floated?
            end

            return false if bundle&.owner&.corporation? && bundle.owner != bundle.corporation

            super
          end

          def get_par_prices(entity, corporation)
            return branch_par_prices(entity, corporation) if @branch_stage == :par

            super.reject { |price| @game.par_price_gated_until_phase_3?(price) }
          end

          def can_par_branch?(corporation, entity)
            @branch_stage == :par &&
              entity == current_entity &&
              corporation == @branch_corporation &&
              !corporation.ipoed
          end

          def available_hex(entity, hex)
            return false unless entity == current_entity

            return hex == selected_land_grant_hex && potential_tiles(entity, hex).any? if
              @branch_stage == :land_grant_upgrade

            false
          end

          def choices_for_ipo_row(entity, company, _ipo_row_number)
            return [] if starting_branch?
            return [] unless entity == current_entity
            return [] if must_sell?(entity) || bought?
            return [] unless available_bank_land_grants.include?(company)

            branch_sponsors(entity, company).map do |sponsor|
              [branch_start_choice_id(company, sponsor), "Start branch railroad for #{sponsor.name}"]
            end
          end

          def may_choose?(company)
            !starting_branch? &&
              available_bank_land_grants.include?(company) &&
              branch_sponsors(current_entity, company).any?
          end

          def potential_tiles(entity_or_entities, hex)
            return [] unless @branch_stage == :land_grant_upgrade
            return [] unless Array(entity_or_entities).include?(current_entity)
            return [] unless hex == selected_land_grant_hex

            @game.land_grant_home_upgrade_tiles(hex)
          end

          def sell_shares(entity, bundle, swap: nil)
            raise GameError, "Cannot sell shares of #{bundle.corporation.name}" if !can_sell?(entity, bundle) && !swap

            @round.players_sold[bundle.owner][bundle.corporation] = :now
            @game.sell_shares_and_change_price(
              bundle,
              swap: swap,
              allow_president_change: allow_president_change?(bundle.corporation),
            )
            clear_branch_start_cache!
          end

          def purchasable_companies(entity)
            return [] if bought? ||
              !available_cash(entity).positive? ||
              !@game.phase ||
              !@game.phase.status.include?('can_buy_companies_from_other_players') ||
              @game.turn == 1

            @game.purchasable_companies(entity)
          end

          private

          def starting_branch?
            !!@branch_stage
          end

          def clear_branch_start_cache!
            @available_bank_land_grants = nil
            @available_land_grants = {}
            @branch_sponsors = {}
            @branch_candidate_sponsors = {}
            @land_grant_usable = {}
            @minimum_branch_par_price = nil
            @unused_branch_corporations = nil
          end

          def branch_start_available?(player)
            # Stock-round branch start is available only if a bank land grant can be used
            # and at least one eligible sponsor exists.
            return false if bought?

            available_bank_land_grants.any? && branch_candidate_sponsors(player).any?
          end

          def branch_start_choices(player)
            return {} if bought?

            branch_sponsors_by_land_grant(player).each_with_object({}) do |(land_grant, sponsors), choices|
              sponsors.each do |sponsor|
                choices[branch_start_choice_id(land_grant, sponsor)] =
                  "Start branch railroad for #{sponsor.name} using #{land_grant.name}"
              end
            end
          end

          def branch_start_choice_id(land_grant, sponsor)
            "#{land_grant.id}|#{sponsor.id}"
          end

          def branch_sponsors(player, land_grant = nil)
            return branch_sponsors_by_land_grant(player).values.flatten.uniq unless land_grant

            @branch_sponsors[[player, land_grant]] ||= branch_sponsors_for_land_grant(player, land_grant)
          end

          def branch_sponsors_by_land_grant(player)
            available_bank_land_grants.to_h do |land_grant|
              [land_grant, branch_sponsors(player, land_grant)]
            end
          end

          def branch_sponsors_for_land_grant(player, land_grant)
            branch_candidate_sponsors(player).select do |corporation|
              branch_sponsor_available?(player, corporation, land_grant)
            end
          end

          def branch_candidate_sponsors(player)
            @branch_candidate_sponsors ||= {}
            @branch_candidate_sponsors[player] ||= @game.all_corporations.select do |corporation|
              branch_sponsor_available?(player, corporation)
            end
          end

          def branch_sponsor_available?(player, corporation, land_grant = nil)
            # Branch sponsors must be root starting corps (no existing branch parentage),
            # operated, and without an unassimilated child branch.
            return false unless corporation&.corporation?
            return false if corporation.closed? || !corporation.floated?
            return false unless @game.starting_corporation?(corporation)
            return false unless corporation.operated?
            return false unless @game.acting_for_entity(corporation) == player
            return false if @game.isolated_branch_descendant?(corporation)
            return false if @game.isolated_branch?(corporation)
            return false if unused_branch_corporations.empty?

            return false if !minimum_branch_par_price || corporation.cash < minimum_branch_par_price * 2
            return true unless land_grant

            available_land_grants(corporation).include?(land_grant)
          end

          def minimum_branch_par_price
            @minimum_branch_par_price ||= @game.stock_market.par_prices
              .reject { |price| @game.par_price_gated_until_phase_3?(price) }
              .map(&:price)
              .min
          end

          def start_branch_from_land_grant_choice(choice)
            land_grant_id, corporation_id = choice.split('|', 2)
            land_grant = available_bank_land_grants.find { |grant| grant.id == land_grant_id }
            sponsor = branch_sponsors(current_entity, land_grant).find { |corporation| corporation.id == corporation_id }
            raise GameError, 'That corporation cannot start a branch railroad' unless sponsor
            raise GameError, 'That land grant cannot be used to start this branch railroad' unless land_grant

            @branch_sponsor = sponsor
            @branch_corporation = unused_branch_corporations.first
            @game.assign_branch_identity(@branch_corporation, @branch_sponsor, branch_city: @game.land_grant_city_name(land_grant))
            @selected_land_grant = land_grant
            @log << "#{current_entity.name} acts for #{@branch_sponsor.name} to start #{@branch_corporation.name}"
            @log << "#{@branch_sponsor.name} selects #{land_grant.name} as #{@branch_corporation.name}'s land grant"

            if @game.land_grant_home_city_available?(selected_land_grant_hex)
              place_land_grant_home_and_continue_to_par!
            else
              @branch_stage = :land_grant_upgrade
              @log << "#{@selected_land_grant.name} must be upgraded before #{@branch_corporation.name}'s home "\
                      'station can be placed'
            end
          end

          def unused_branch_corporations
            @unused_branch_corporations ||= @game.available_branches.select { |corporation| corporation.presidents_share.buyable }
          end

          def available_bank_land_grants
            @available_bank_land_grants ||= @game.land_grants.select do |land_grant|
              land_grant.owner == @game.bank && !land_grant.closed?
            end
          end

          def available_land_grants(sponsor)
            @available_land_grants[sponsor] ||= available_bank_land_grants.select do |land_grant|
              usable_land_grant?(land_grant, sponsor) &&
                @game.genealogy_land_grant_territory_available?(sponsor, land_grant)
            end
          end

          def usable_land_grant?(land_grant, sponsor)
            @land_grant_usable[land_grant] = @game.usable_land_grant?(land_grant, sponsor) unless
              @land_grant_usable.key?(land_grant)

            @land_grant_usable[land_grant]
          end

          def selected_land_grant_hex
            @game.hex_by_id(@game.land_grant_hex_id(@selected_land_grant))
          end

          def place_land_grant_home_and_continue_to_par!
            @game.place_branch_land_grant_home(
              @branch_corporation,
              @branch_sponsor,
              @selected_land_grant,
            )
            @branch_stage = :par
          end

          def branch_par_prices(entity, corporation)
            return [] unless can_par_branch?(corporation, entity)

            @game.stock_market.par_prices
              .reject { |price| @game.par_price_gated_until_phase_3?(price) }
              .select { |price| @branch_sponsor.cash >= price.price * 2 }
          end

          def process_branch_par(action)
            raise GameError, 'That branch railroad cannot be parred' unless
              branch_par_prices(action.entity, action.corporation).include?(action.share_price)

            corporation = action.corporation
            @game.stock_market.set_par(corporation, action.share_price)
            @game.share_pool.transfer_shares(
              corporation.presidents_share.to_bundle,
              @branch_sponsor,
              spender: @branch_sponsor,
              receiver: corporation,
              price: action.share_price.price * 2,
              allow_president_change: false,
              corporate_transfer: true,
            )
            corporation.owner = @branch_sponsor
            corporation.ipoed = true
            @game.after_par(corporation)
            @round.players_bought[action.entity][corporation] += corporation.presidents_share.percent
            track_action(action, corporation)
            @branch_stage = :shares
            @log << "#{@branch_sponsor.name} pars #{corporation.name} at "\
                    "#{@game.format_currency(action.share_price.price)} and buys its 20% president's certificate"
          end

          def branch_share_purchase_actions(_entity)
            actions = []
            actions << 'buy_shares' if branch_share_buy_available?
            actions << 'pass'
            actions
          end

          def branch_share_buy_available?
            return false if additional_branch_shares_bought >= 2

            available_branch_shares.any? { |share| can_buy_branch_share?(current_entity, share.to_bundle) }
          end

          def available_branch_shares
            @branch_corporation.shares.select do |share|
              share.owner == @branch_corporation && !share.president && share.buyable
            end
          end

          def additional_branch_shares_bought
            [(@branch_sponsor.percent_of(@branch_corporation) - 20) / 10, 0].max
          end

          def can_buy_branch_share?(entity, bundle)
            return false if entity != current_entity
            return false if bundle&.corporation != @branch_corporation
            return false if bundle.owner != @branch_corporation || bundle.percent != 10 || !bundle.buyable
            return false if additional_branch_shares_bought >= 2

            @branch_sponsor.cash >= bundle.price
          end

          def process_branch_buy_shares(action)
            raise GameError, 'That branch share cannot be purchased' unless can_buy_branch_share?(action.entity, action.bundle)

            @game.share_pool.transfer_shares(
              action.bundle,
              @branch_sponsor,
              spender: @branch_sponsor,
              receiver: @branch_corporation,
              price: action.bundle.price,
              allow_president_change: false,
              corporate_transfer: true,
            )
            @round.players_bought[action.entity][@branch_corporation] += action.bundle.percent
            track_action(action, @branch_corporation)
            @log << "#{@branch_sponsor.name} buys a 10% share of #{@branch_corporation.name} for "\
                    "#{@game.format_currency(action.bundle.price)}"
            finish_branch_share_buying! unless branch_share_buy_available?
          end

          def finish_branch_share_buying!
            home_city = @branch_corporation.tokens.find(&:used)&.city
            raise GameError, "#{@branch_corporation.name}'s home station has not been placed" unless home_city

            @game.purchase_starting_tokens(@branch_corporation, home_city: home_city)
            @branch_corporation.floated = true
            @log << "#{@branch_sponsor.name} finishes buying shares of #{@branch_corporation.name}"
            pass!
          end
        end
      end
    end
  end
end
