# frozen_string_literal: true

require_relative '../../../step/passable_auction'

module Engine
  module Game
    module G18IL
      module Step
        class SelectionAuction < Engine::Step::SelectionAuction
          SHARE_VALUE_ROUND = 5
          def setup
            @game.players.each(&:unpass!)
            @bought_shares = []
            @big_lot_winner = nil
            @big_lot_current_entity = nil
            setup_auction
            company_setup

            while !@auctioning && @companies.any? && current_entity&.player? && current_entity.cash < starting_bid(min_company)
              @log << "#{current_entity.name} declines to start an auction (insufficient cash)"
              current_entity.pass!
              break if entities.all?(&:passed?)

              @round.next_entity_index!
            end
          end

          def company_setup
            if @game.big_lots_first_turn?
              @companies = @game.lot_proxies.reject(&:closed?)
              @big_lot_current_entity = initial_auction_entities.first
              auction_entity(@game.lot_choice_proxy)
              return
            end

            concessions = @game.companies.select { |c| c.meta[:type] == :concession && !c.owner&.player? }
            @companies = concessions.sort_by { |c| [c.meta[:share_count], c.sym] }
            @companies.each { |c| change_private_description(c) }

            if @game.privates_in_auction_pool?
              undrafted = @game.companies.select do |c|
                c.meta[:type] == :private && c.owner.nil? && !c.closed?
              end
              @companies += undrafted.sort_by { |c| [c.meta[:class].to_s, c.sym] }
            end

            prepare_ic_shares if @game.ic_formation_triggered? && !@game.ic.ipo_shares.empty?
          end

          def change_private_description(company)
            corp = @game.corporations.find { |c| c.name == company.sym }
            share_count = company&.meta&.[](:share_count)

            base = "Can start #{bold(company.sym)}#{corp&.coordinates ? " (#{corp.coordinates})" : ''} as a #{share_count}-share corporation."

            if corp && (corp.cash.positive? || corp.trains.any?)
              cash_part = corp.cash.positive? ? @game.format_currency(corp.cash) : nil

              if corp.trains.any?
                items = corp.trains.map { |train| train.name.match?(/^\d$/) ? "#{train.name}-" : train.name }
                if items.size == 1
                  name = items.first
                  trains_part = name.end_with?('-') ? "#{name}train" : "#{name} train"
                else
                  list = cash_part ? items.join(', ') : @game.list_with_and(items)
                  trains_part = "#{list} train"
                end
              end

              parts = [cash_part, trains_part].compact
              base += "\n\n#{bold('Corporation holdings')}: #{parts.join(' and ')}" unless parts.empty?
            end

            if corp
              a = corp.companies.find { |p| p.meta&.[](:type) == :private && p.meta&.[](:class) == :A }
              b = corp.companies.find { |p| p.meta&.[](:type) == :private && p.meta&.[](:class) == :B }
              if a || b
                base += "\nStarts with:"
                base += "\n\n#{bold(a.name.upcase)}\n#{a.desc}" if a
                base += "\n\n#{bold(b.name.upcase)}\n#{b.desc}" if b
              end
            end

            company.desc = base
          end

          def prepare_ic_shares
            ic = @game.ic
            return unless ic.share_price

            ic_shares = assign_share_values(:share, ic.share_price.price)
            ic_presidents_share = assign_share_values(:presidents_share, ic.share_price.price * 2)

            shares_to_add = ic.shares.count { |s| !s.president && s.owner == ic }
            @companies += ic_presidents_share if @game.ic_in_receivership?
            @companies += ic_shares.take(shares_to_add) if shares_to_add.positive?
          end

          def assign_share_values(type, value)
            @game.companies.select { |c| c.meta[:type] == type }.each { |c| c.value = up_to_nearest_five(value) }
          end

          def up_to_nearest_five(num)
            return num if (num % SHARE_VALUE_ROUND).zero?

            up_to_nearest_five(num + 1)
          end

          def actions(entity)
            return entity == @big_lot_winner ? %w[bid] : [] if @big_lot_winner
            return [] if entities.all?(&:passed?)
            return [] if @companies.empty?

            entity == current_entity ? ACTIONS : []
          end

          def active_entities
            if @game.big_lots_first_turn?
              return [@big_lot_winner] if @big_lot_winner
              return [] if @companies.empty?

              if @auctioning == @game.lot_choice_proxy
                if (winning_bid = highest_bid(@auctioning))
                  index = @active_bidders.index(winning_bid.entity)
                  return [@active_bidders[(index + 1) % @active_bidders.size]] if index && @active_bidders.any?
                end

                return [@big_lot_current_entity || @active_bidders.first || entities.first].compact
              end
            end

            return super unless auctioning
            return [] if @active_bidders.empty?

            if (winning_bid = highest_bid(@auctioning))
              index = @active_bidders.index(winning_bid.entity)
              return [@active_bidders[(index + 1) % @active_bidders.size]] if index
            end

            [@active_bidders.first]
          end

          def description
            return 'Choose a Lot' if @big_lot_winner
            return 'Bid for the Right to Choose a Lot' if @game.big_lots_first_turn?
            return 'Bid on Selected Concession' if @auctioning&.meta&.[](:type) == :concession
            return 'Bid on Selected Private' if @auctioning&.meta&.[](:type) == :private
            return 'Bid on Selected Share' if @auctioning

            'Bid on Auction Pool Item'
          end

          def pass_description
            return 'Decline' if @game.big_lots_first_turn?
            return 'Decline' unless @auctioning

            if @auctioning.meta[:type] == :concession
              "Pass (on #{@auctioning.id})"
            else
              "Pass (on #{@auctioning.name})"
            end
          end

          def help
            str = []
            if @game.big_lots_first_turn?
              str << if @big_lot_winner
                       if @game.available_big_lot_indices.size == 2
                         'Choose one lot. The final player receives the remaining lot for free.'
                       else
                         'Choose one of the available lots. The remaining players will bid again.'
                       end
                     else
                       'Bid for the right to choose a lot, or decline. If everyone still eligible declines before '\
                         'anyone bids, the available lots are assigned randomly among them.'
                     end
              return str
            end

            return str if @auctioning && @auctioning.meta[:type] != :concession

            if !@game.intro_game? &&
              @companies.any? do |c|
                c.meta[:type] == :concession &&
                @game.corporations.find { |corp| corp.name == c.sym }.companies.any?
              end
              str << ['The assigned Class A and Class B privates are described on each concession card.']
            end

            unless @auctioning
              str << '—' unless str.empty?
              str << 'Start an auction or decline:'
            end
            str
          end

          def show_map
            true
          end

          def tiered_auction_companies
            if @game.big_lots_first_turn?
              privates = @game.lots.flatten.select { |company| company.meta[:type] == :private }
              return [
                @game.lot_proxies.reject(&:closed?),
                privates.select { |company| company.meta[:class] == :A },
                privates.select { |company| company.meta[:class] == :B },
              ].reject(&:empty?)
            end

            return [@companies] if @companies.nil? || @companies.empty? || @game.intro_game?

            concessions     = @companies.select { |c| c.meta&.[](:type) == :concession }
            non_concessions = @companies - concessions

            tiers = [concessions]

            if @game.privates_in_auction_pool?
              privates_in_row = non_concessions.select { |c| c.meta&.[](:type) == :private }
              ic_shares = non_concessions - privates_in_row
              tiers << privates_in_row unless privates_in_row.empty?
              tiers << ic_shares unless ic_shares.empty?
            else
              tiers << non_concessions unless non_concessions.empty?
            end

            tiers
          end

          BOLD_MAP = {
            'A' => '𝐀', 'B' => '𝐁', 'C' => '𝐂', 'D' => '𝐃', 'E' => '𝐄',
            'F' => '𝐅', 'G' => '𝐆', 'H' => '𝐇', 'I' => '𝐈', 'J' => '𝐉',
            'K' => '𝐊', 'L' => '𝐋', 'M' => '𝐌', 'N' => '𝐍', 'O' => '𝐎',
            'P' => '𝐏', 'Q' => '𝐐', 'R' => '𝐑', 'S' => '𝐒', 'T' => '𝐓',
            'U' => '𝐔', 'V' => '𝐕', 'W' => '𝐖', 'X' => '𝐗', 'Y' => '𝐘',
            'Z' => '𝐙',
            'a' => '𝐚', 'b' => '𝐛', 'c' => '𝐜', 'd' => '𝐝', 'e' => '𝐞',
            'f' => '𝐟', 'g' => '𝐠', 'h' => '𝐡', 'i' => '𝐢', 'j' => '𝐣',
            'k' => '𝐤', 'l' => '𝐥', 'm' => '𝐦', 'n' => '𝐧', 'o' => '𝐨',
            'p' => '𝐩', 'q' => '𝐪', 'r' => '𝐫', 's' => '𝐬', 't' => '𝐭',
            'u' => '𝐮', 'v' => '𝐯', 'w' => '𝐰', 'x' => '𝐱', 'y' => '𝐲',
            'z' => '𝐳',
          }.freeze

          def bold(str)
            str.gsub(/./) { |c| BOLD_MAP[c] || c }
          end

          def process_pass(action, reason = nil)
            entity = action.entity

            if @game.big_lots_first_turn? && @auctioning == @game.lot_choice_proxy
              pass_auction(entity)
              resolve_bids
            elsif auctioning
              pass_auction(entity)
              resolve_bids
            else
              msg = "#{entity.name} declines to start an auction"
              msg += " (#{reason})" if reason
              @log << msg
              entity.pass!
              if entities.all?(&:passed?) && @game.big_lots_first_turn?
                @log << 'All remaining players pass without making an opening bid; the remaining lots are assigned randomly'
                @game.resolve_big_lots_randomly!
                @companies.clear
                return pass!
              end
              return pass! if entities.all?(&:passed?) || @companies.empty?

              next_entity!
            end

            pass! if @companies.none?
          end

          def next_entity!
            @round.next_entity_index!
            entity = entities[entity_index]
            entity.pass! if @auctioning && entity && max_bid(entity, @auctioning) < min_bid(@auctioning)

            if !@auctioning && @companies.any? && entity&.player? && !entity.passed? &&
                  entity.cash < starting_bid(min_company)
              return process_pass(Engine::Action::Pass.new(entity), 'insufficient cash')
            end

            next_entity! if entity&.passed?
          end

          def process_bid(action)
            if @big_lot_winner
              company = action.company
              raise GameError, 'Only the auction winner may choose a lot' unless action.entity == @big_lot_winner
              raise GameError, 'Choose an available lot' unless available_big_lot_proxies.include?(company)

              lot_index = company.meta[:lot_index]
              winner = @big_lot_winner
              @big_lot_winner = nil
              finish_big_lot_choice(winner, lot_index)
              return
            end

            if @game.big_lots_first_turn? && @auctioning == @game.lot_choice_proxy
              if @bids[@auctioning].empty?
                entities.each(&:unpass!)
                @active_bidders = entities.dup
              end
              action.entity.unpass!
              add_bid(action)
              resolve_bids if @active_bidders.one?
              return
            end

            entities.each(&:unpass!) if @game.big_lots_first_turn? && !auctioning
            super
          end

          def pass_auction(entity)
            if @game.big_lots_first_turn?
              if @bids[@auctioning].empty?
                @log << "#{entity.name} declines to make an opening bid"
              else
                @log << "#{entity.name} declines to bid"
              end
              @bids[@auctioning]&.reject! { |bid| bid.entity == entity }
              @active_bidders.delete(entity)
              entity.pass!
              @big_lot_current_entity = @active_bidders.first
              return
            end

            super
          end

          def bid_target(bid)
            return @game.lot_choice_proxy if @game.big_lots_first_turn?

            super
          end

          def add_bid(bid)
            company = bid_target(bid)
            if @game.big_lots_first_turn? && company.meta[:type] != :lot_choice
              raise GameError, 'Only the right to choose a lot may be bid on during the Big Lots auction'
            end

            entity = bid.entity
            price  = bid.price
            min    = min_bid(company)
            raise GameError, "No minimum bid available for #{company.name}" unless min

            raise GameError, "Minimum bid is #{@game.format_currency(min)} for #{company.name}" if price < min
            if must_bid_increment_multiple? && ((price - min) % @game.class::MIN_BID_INCREMENT).nonzero?
              raise GameError, "Must increase bid by a multiple of #{@game.class::MIN_BID_INCREMENT}"
            end
            if price > max_bid(entity, company)
              raise GameError, "Cannot afford bid. Maximum possible bid is #{max_bid(entity, company)}"
            end

            bids = (@bids[company] ||= [])
            bids.reject! { |b| b.entity == entity }
            bids << bid

            if @game.big_lots_first_turn? && company.meta[:type] == :lot_choice
              @log << "#{entity.name} bids #{@game.format_currency(price)}"
            else
              @log << "#{entity.name} bids #{@game.format_currency(price)} for #{company.name}"
            end

            return unless @auctioning

            min = min_bid(@auctioning)
            passing = @active_bidders.reject { |p| p == entity || max_bid(p, @auctioning) >= min }
            passing.each do |p|
              @game.log << "#{p.name} cannot bid #{@game.format_currency(min)} and is out of the auction for #{@auctioning.name}"
              remove_from_auction(p)
            end
          end

          def win_bid(winner, company)
            player = winner.entity
            price  = winner.price
            case company.meta[:type]
            when :lot_choice
              @log << "#{player.name} wins the right to choose a lot with a bid of #{@game.format_currency(price)}"
              player.spend(price, @game.bank)
            when :share, :presidents_share
              @log << "#{player.name} wins the auction for #{company.name} with a bid of #{@game.format_currency(price)}"
              @log << "#{@game.ic.name} receives #{@game.format_currency(price)}"
              player.spend(price, @game.ic)
            else
              super
            end
          end

          def resolve_bids
            if @game.big_lots_first_turn? && @auctioning == @game.lot_choice_proxy
              if @active_bidders.none? && @bids[@auctioning].empty?
                @log << 'All remaining players decline to make an opening bid; the remaining lots are assigned randomly'
                @bids.clear
                @active_bidders.clear
                @auctioning = nil
                @game.resolve_big_lots_randomly!
                @companies.clear
                return pass!
              end

              return unless @active_bidders.one? && @bids[@auctioning].any?

              winner = highest_bid(@auctioning)
              company = @auctioning
              win_bid(winner, company)

              @bids.clear
              @active_bidders.clear
              @auctioning = nil
              post_win_bid(winner, company)
              return
            end

            super
            return if @big_lot_winner
            return pass! if @companies.none?

            entities.each(&:unpass!)
            @round.goto_entity!(@auction_triggerer)
            next_entity!
          end

          def post_win_bid(winner, company)
            player = winner.entity
            ic     = @game.ic

            case company.meta[:type]
            when :lot_choice
              @big_lot_winner = player
              @round.goto_entity!(player)
              return
            when :share
              @game.share_pool.transfer_shares(ShareBundle.new(ic.shares.last), player)

              @game.companies.delete(company)
              @companies.delete(company)
              company.close!

              @game.sync_ic_operating_state!

              if (pres = @game.company_by_id('ICP')) && !@game.ic_in_receivership?
                @companies.delete(pres)
                @game.companies.delete(pres)
                pres.close!
              end

              refresh_ic_share_proxies!

            when :presidents_share
              @game.share_pool.transfer_shares(ShareBundle.new(ic.shares.first), player)

              @game.companies.delete(company)
              @companies.delete(company)
              company.close!

              @game.sync_ic_operating_state!
              refresh_ic_share_proxies!

            when :concession
              corp = @game.corporations.find { |c| c.name == company.sym }
              return unless corp

              assigned = corp.companies.select do |p|
                p.meta&.[](:type) == :private && %i[A B].include?(p.meta[:class])
              end

              (@companies ||= []).delete(company)
              assigned.each { |p| @companies.delete(p) }
            end
          end

          def refresh_ic_share_proxies!
            @companies.reject! { |c| c.meta && %i[share presidents_share].include?(c.meta[:type]) }

            prepare_ic_shares if @game.ic_formation_triggered? && !@game.ic.ipo_shares.empty?

            @companies.sort_by! { |c| [c.meta[:type], c.meta[:share_count], c.sym] }
          end

          def may_bid?(company = nil)
            if @big_lot_winner
              return false unless company

              return available_big_lot_proxies.include?(company)
            end

            if @game.big_lots_first_turn?
              return false if company

              return true
            end

            return true if company.meta&.[](:type) == :lot

            if company.meta&.[](:type) == :private
              return @game.privates_in_auction_pool? && company.owner.nil?
            end

            true
          end

          def starting_bid(company)
            return 10 if company&.meta&.[](:type) == :lot_choice
            return 10 if !company || company&.meta&.[](:type) == :concession
            return 10 if @game.privates_in_auction_pool? && company&.meta&.[](:type) == :private

            company.min_bid
          end

          def min_bid(company)
            if @big_lot_winner && @game.lot_proxies.include?(company)
              return 0
            end

            if !@auctioning && @game.privates_in_auction_pool? && company&.meta&.[](:type) == :private
              return 10
            end

            super
          end

          def max_bid(entity, _company)
            return 0 if @big_lot_winner

            raw = entity.cash
            inc = @game.class::MIN_BID_INCREMENT
            raw - (raw % inc)
          end

          def min_company
            return nil if @companies.nil? || @companies.empty?

            # Concessions always start at the $10 minimum.
            min_value_company = @companies.min_by(&:value)
            min_value = [min_value_company.value, 10].min

            @companies.find { |c| c.value == min_value } || min_value_company
          end

          def auctioning
            if @game.big_lots_first_turn? && @auctioning == @game.lot_choice_proxy && !@big_lot_winner
              return :turn
            end

            super
          end

          def may_choose?(company)
            return false unless @big_lot_winner

            available_big_lot_proxies.include?(company)
          end

          def min_player_bid
            min_bid(@game.lot_choice_proxy)
          end

          def max_player_bid(entity)
            max_bid(entity, @game.lot_choice_proxy)
          end

          def choice_available?(entity)
            entity == @big_lot_winner
          end

          def choice_name
            'Choose a lot'
          end

          def choices
            return {} unless @big_lot_winner

            available_big_lot_proxies.to_h { |lot| [lot.meta[:lot_index].to_s, lot.name] }
          end

          def process_choose(action)
            raise GameError, 'Only the auction winner may choose a lot' unless action.entity == @big_lot_winner

            unless choices.key?(action.choice)
              raise GameError, "Invalid lot choice: #{action.choice}"
            end

            lot_index = action.choice.to_i
            winner = @big_lot_winner
            @big_lot_winner = nil
            finish_big_lot_choice(winner, lot_index)
          end

          def initial_auction_entities
            players = super
            return players unless @game.big_lots_first_turn?

            players.select { |player| @game.big_lot_unassigned_players.include?(player) }
          end

          private

          def available_big_lot_proxies
            @game.lot_proxies.reject(&:closed?)
          end

          def finish_big_lot_choice(winner, lot_index)
            if @game.resolve_big_lots!(winner, lot_index)
              @companies.clear
              pass!
              return
            end

            @companies = available_big_lot_proxies
            entities.each do |entity|
              if @game.big_lot_unassigned_players.include?(entity)
                entity.unpass!
              else
                entity.pass!
              end
            end

            remaining = @game.big_lot_unassigned_players
            winner_index = entities.index(winner)
            next_player = entities.rotate(winner_index + 1).find { |entity| remaining.include?(entity) }
            @big_lot_current_entity = next_player
            @round.goto_entity!(next_player)
            auction_entity(@game.lot_choice_proxy)
          end
        end
      end
    end
  end
end
