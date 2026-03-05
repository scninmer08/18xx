# frozen_string_literal: true

require_relative '../../../step/passable_auction'

module Engine
  module Game
    module G18IL
      module Step
        class SelectionAuction < Engine::Step::SelectionAuction
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

          def tiered_auction_companies
            return [@companies] if @companies.nil? || @companies.empty? || @game.intro_game?

            concessions     = @companies.select { |c| c.meta&.[](:type) == :concession }
            non_concessions = @companies - concessions

            tiers = concessions.map do |con|
              corp = @game.corporations.find { |co| co.name == con.sym }
              attached = []
              if corp
                a = corp.companies.find { |p| p.meta&.[](:type) == :private && p.meta&.[](:class) == :A }
                b = corp.companies.find { |p| p.meta&.[](:type) == :private && p.meta&.[](:class) == :B }
                attached << a if a
                attached << b if b
              end
              [con, *attached]
            end

            tiers << non_concessions

            tiers
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

          def company_setup
            if lots_first_turn?
              @companies = @game.lot_proxies
            else
              concessions = @game.companies.select { |c| c.meta[:type] == :concession && !c.owner&.player? }
              @companies = concessions.sort_by { |c| [c.meta[:share_count], c.sym] }
              @companies.each { |c| change_private_description(c) }
              prepare_ic_shares if @game.ic_formation_triggered? && !@game.ic.ipo_shares.empty?
            end
          end

          def change_private_description(company)
            corp = @game.corporations.find { |c| c.name == company.sym }
            share_count = company&.meta&.[](:share_count)

            names = corp.companies.map { |c| c&.name }.compact
            base = "Can start #{company.sym} as a #{share_count}-share corporation."
            base += " Starts with #{names.join(' and ')}." if names.any?

            holdings = nil

            if corp && (corp.cash.positive? || corp.trains.any?)
              cash_part = corp.cash.positive? ? @game.format_currency(corp.cash) : nil

              if corp.trains.any?
                items = corp.trains.map { |t| t.name.match?(/^\d$/) ? "#{t.name}-" : t.name }
                if items.size == 1
                  name = items.first
                  trains_part = name.end_with?('-') ? "#{name}train" : "#{name} train"
                else
                  list = cash_part ? items.join(', ') : @game.list_with_and(items)
                  trains_part = "#{list} train"
                end
              end

              parts = [cash_part, trains_part].compact
              holdings = "\nCorporation holdings: #{parts.join(' and ')}" unless parts.empty?
            end

            company.desc = "#{base}#{holdings}"
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
            return num if (num % 5).zero?

            up_to_nearest_five(num + 1)
          end

          def starting_bid(company)
            return 10 if !company || company&.meta&.[](:type) == :concession

            company.min_bid
          end

          def may_bid?(company = nil)
            return false if company.meta&.[](:type) == :private

            true
          end

          def actions(entity)
            return [] if entities.all?(&:passed?)
            return [] if @companies.empty?
            return %w[bid] if lots_first_turn? && !@auctioning

            entity == current_entity ? ACTIONS : []
          end

          def lots_first_turn?
            @game.lots_variant? && @game.turn == 1
          end

          def show_map
            true
          end

          def help
            str = []
            return str if @auctioning && @auctioning.meta[:type] != :concession

            if lots_first_turn? && !@auctioning
              str << 'Choose one Lot to start an auction. The winner receives all four concessions in that lot; '\
                     'the other player receives the remaining lot for free.'
              return str
            end

            if !@game.intro_game? &&
              @companies.any? do |c|
                c.meta[:type] == :concession &&
                @game.corporations.find { |corp| corp.name == c.sym }.companies.any?
              end
              str << [
                "The private companies attached to each concession are shown next to the concession's card.",
              ]
            end

            unless @auctioning
              str << '—' unless str.empty?
              str << 'Start an auction or decline:'
            end
            str
          end

          def description
            return (@auctioning ? 'Bid on Selected Lot' : 'Bid on Lot') if lots_first_turn?
            return 'Bid on Selected Concession' if @auctioning&.meta&.[](:type) == :concession
            return 'Bid on Selected Share' if @auctioning

            @companies&.any? { |c| c.meta&.[](:type) == :share } ? 'Bid on Concession or Share' : 'Bid on Concession'
          end

          def pass_description
            return 'Decline' unless @auctioning

            if @auctioning.meta[:type] == :concession
              "Pass (on #{@auctioning.id})"
            else
              "Pass (on #{@auctioning.name})"
            end
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

            return pass! if @companies.none?
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
            when :lot
              @log << "#{player.name} wins the auction for #{company.name} with a bid of #{@game.format_currency(price)}"
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
            super
            return pass! if @companies.none?

            entities.each(&:unpass!)
            @round.goto_entity!(@auction_triggerer)
            next_entity!
          end

          def resolve_lot!(winner_player, lot_idx)
            other_player = (@game.players - [winner_player]).first
            lot_won  = @game.lots[lot_idx]
            lot_free = @game.lots[1 - lot_idx]

            lot_won.each  { |corp| assign_company(@game.company_by_id(corp.name), winner_player) }
            lot_free.each { |corp| assign_company(@game.company_by_id(corp.name), other_player) }

            @log << "#{winner_player.name} wins Lot #{lot_idx + 1} and receives: #{lot_won.map(&:name).join(', ')}"
            @log << "#{other_player.name} receives Lot #{2 - lot_idx} with: #{lot_free.map(&:name).join(', ')}"

            tokens = Array(@game.lot_proxies)
            tokens.each(&:close!)
            @companies&.delete_if { |c| tokens.include?(c) }
            @game.companies.delete_if { |c| tokens.include?(c) }
          end

          def post_win_bid(winner, company)
            resolve_lot!(winner.entity, company.meta[:lot_index]) if company.meta[:type] == :lot

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
            end
          end

          def refresh_ic_share_proxies!
            @companies.reject! { |c| c.meta && %i[share presidents_share].include?(c.meta[:type]) }

            prepare_ic_shares if @game.ic_formation_triggered? && !@game.ic.ipo_shares.empty?

            @companies.sort_by! { |c| [c.meta[:type], c.meta[:share_count], c.sym] }
          end
        end
      end
    end
  end
end
