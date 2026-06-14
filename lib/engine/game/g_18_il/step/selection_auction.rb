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
            return [] if entities.all?(&:passed?)
            return [] if @companies.empty?
            entity == current_entity ? ACTIONS : []
          end

          def description
            return 'Bid on Selected Concession' if @auctioning&.meta&.[](:type) == :concession
            return 'Bid on Selected Private' if @auctioning&.meta&.[](:type) == :private
            return 'Bid on Selected Share' if @auctioning

            'Bid on Auction Pool Item'
          end

          def pass_description
            return 'Decline' unless @auctioning

            if @auctioning.meta[:type] == :concession
              "Pass (on #{@auctioning.id})"
            else
              "Pass (on #{@auctioning.name})"
            end
          end

          def help
            str = []
            return str if @auctioning && @auctioning.meta[:type] != :concession

            if !@game.intro_game? &&
              @companies.any? do |c|
                c.meta[:type] == :concession &&
                @game.corporations.find { |corp| corp.name == c.sym }.companies.any?
              end
              str << ['The attached Class A and Class B privates are described on each concession card.']
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

            if auctioning
              pass_auction(entity)
              resolve_bids
            else
              msg = "#{entity.name} declines to start an auction"
              msg += " (#{reason})" if reason
              @log << msg
              entity.pass!
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

          def add_bid(bid)
            company = bid_target(bid)
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

            @log << "#{entity.name} bids #{@game.format_currency(price)} for #{company.name}"

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
            when :share, :presidents_share
              @log << "#{player.name} wins the auction for #{company.name} with a bid of #{@game.format_currency(price)}"
              @log << "#{@game.ic.name} receives #{@game.format_currency(price)}"
              player.spend(price, @game.ic)
            else
              super
            end
          end

          def resolve_bids
            super
            return pass! if @companies.none?

            entities.each(&:unpass!)
            @round.goto_entity!(@auction_triggerer)
            next_entity!
          end

          def post_win_bid(winner, company)
            player = winner.entity
            ic     = @game.ic

            case company.meta[:type]
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

              attached = corp.companies.select do |p|
                p.meta&.[](:type) == :private && %i[A B].include?(p.meta[:class])
              end

              (@companies ||= []).delete(company)
              attached.each { |p| @companies.delete(p) }
            when :private
              @game.update_private_name!(company)
            end
          end

          def refresh_ic_share_proxies!
            @companies.reject! { |c| c.meta && %i[share presidents_share].include?(c.meta[:type]) }

            prepare_ic_shares if @game.ic_formation_triggered? && !@game.ic.ipo_shares.empty?

            @companies.sort_by! { |c| [c.meta[:type], c.meta[:share_count], c.sym] }
          end

          def may_bid?(company = nil)
            if company.meta&.[](:type) == :private
              return @game.privates_in_auction_pool? && company.owner.nil?
            end

            true
          end

          def starting_bid(company)
            return 10 if !company || company&.meta&.[](:type) == :concession
            return 10 if @game.privates_in_auction_pool? && company&.meta&.[](:type) == :private

            company.min_bid
          end

          def min_bid(company)
            if !@auctioning && @game.privates_in_auction_pool? && company&.meta&.[](:type) == :private
              return 10
            end

            super
          end

          def max_bid(entity, _company)
            raw = entity.cash
            inc = @game.class::MIN_BID_INCREMENT
            raw - (raw % inc)
          end

          def min_company
            return nil if @companies.nil? || @companies.empty?

            # concessions always start at $10 minimum
            min_value_company = @companies.min_by(&:value)
            min_value = [min_value_company.value, 10].min

            @companies.find { |c| c.value == min_value } || min_value_company
          end
        end
      end
    end
  end
end
