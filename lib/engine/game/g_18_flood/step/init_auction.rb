# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../action/par'

module Engine
  module Game
    module G18FLOOD
      module Step
        class InitAuction < Engine::Step::Base
          attr_reader :companies

          AUCTION_ACTIONS = %w[bid pass].freeze
          BUY_ACTION      = %w[bid par].freeze
          PASS_ACTION     = %w[pass].freeze
          MIN_BID_RAISE   = 5

          SEED_AMOUNT = 1_200

          def setup
            @companies       = @game.corporations.dup.reject { |c| c.type == :shell }
            @bids            = {}
            @out_of_auction  = []
            @auction_open    = true
            @auction_winner  = nil
            setup_auction
          end

          def available
            # No affordability filter needed anymore; starting a corp costs the player nothing at par.
            @companies
          end

          def may_purchase?(_company)
            true
          end

          def auctioning
            :turn if @auction_open
          end

          def bids
            {}
          end

          def visible?
            true
          end

          def players_visible?
            true
          end

          def name
            'Buy/Par'
          end

          def description
            in_auction? ? 'Bid on turn to start a corporation' : 'You must start a corporation'
          end

          def finished?
            @companies.empty? || eligible_players.empty?
          end

          def actions(entity)
            return [] if finished?
            return [] unless entity == current_entity

            if @auction_open
              if any_bid?
                # Only compare against cash on hand; no hidden “+ par cost” anymore.
                return AUCTION_ACTIONS if min_player_bid <= entity.cash

                PASS_ACTION
              else
                return %w[bid] if min_player_bid <= entity.cash

                []
              end
            else
              %w[par]
            end
          end

          def choice_name
            'Select a corporation to start'
          end

          def process_par(action)
            corporation = action.corporation
            entity      = action.entity

            # Use the default par if none was sent (or just ignore the UI’s choice)
            share_price = action.share_price || @game.par_prices(corporation).find do |p|
              p.price == @game.class::NATIONAL_STARTING_PRICE
            end
            raise GameError, "#{corporation} cannot be parred" unless @game.can_par?(corporation, entity)

            # Set par as usual
            @game.stock_market.set_par(corporation, share_price)

            # Seed treasury from the BANK (not the player)
            @game.bank.spend(SEED_AMOUNT, corporation)

            # Transfer 100% of IPO to the winner for free
            # Build the bundle from ALL IPO shares
            ipo_shares = corporation.shares # (in this engine, these are the IPO shares after par)
            bundle     = Engine::ShareBundle.new(ipo_shares)
            @game.share_pool.transfer_shares(bundle, entity, allow_president_change: true, price: 0)

            @log << "#{entity.name} starts #{corporation.name} at #{@game.format_currency(share_price.price)}"
            @log << "Bank seeds #{@game.format_currency(SEED_AMOUNT)} to its treasury"
            @log << "#{entity.name} receives ten equity certificates"

            @game.place_home_token(corporation)
            @companies.delete(corporation)

            @out_of_auction << entity unless @out_of_auction.include?(entity)

            @auction_winner = nil
            @auction_open   = true
            setup_auction
          end

          def process_pass(action)
            raise GameError, 'Cannot pass before any bid has been made' unless any_bid?

            player = action.entity
            @log << "#{player.name} passes bidding"
            @bids.delete(player)
            resolve_auction
          end

          def process_bid(action)
            player = action.entity
            price  = action.price

            unless in_auction?
              buy_company(player, action.company, price)
              return
            end

            if price > max_player_bid(player)
              raise GameError,
                    "Cannot afford bid. Maximum possible bid is #{max_player_bid(player)}"
            end
            raise GameError, "Must bid at least #{min_player_bid}" if price < min_player_bid

            @log << "#{player.name} bids #{@game.format_currency(price)}"
            @bids[player] = price
            resolve_auction
          end

          def get_par_prices(entity, corp)
            return [] if @auction_open
            return [] unless entity == current_entity

            # No cash filter: par doesn’t cost the player anything anymore.
            @game.par_prices(corp)
          end

          def active_entities
            return [@bids.min_by { |_k, v| v }.first] if in_auction?

            super
          end

          def min_increment
            1
          end

          def min_player_bid
            any_bid? ? highest_player_bid + MIN_BID_RAISE : 0
          end

          def max_player_bid(entity)
            # Only limited by cash on hand now.
            entity.cash
          end

          def min_bid(company)
            return unless company

            company.value
          end

          def companies_pending_par
            false
          end

          def visible
            true
          end

          def committed_cash(player, _show_hidden = false)
            # Only the bid itself is committed during the auction.
            bid = @bids[player]
            bid && bid >= 0 ? bid : 0
          end

          private

          def eligible_players
            entities - @out_of_auction
          end

          def in_auction?
            @bids.any?
          end

          def any_bid?
            return false unless @bids.any?

            @bids.values.max && @bids.values.max >= 0
          end

          def highest_player_bid
            return 0 unless @bids.any?

            max = @bids.max_by { |_k, v| v }.last
            max >= 0 ? max : 0
          end

          def highest_bid
            highest_player_bid
          end

          def cheapest_thing
            # Kept for structure; no longer used for affordability gates.
            @companies.min_by do |c|
              if c.company?
                c.value
              else
                (@game.par_prices(c).map(&:price).min || 0) * 10
              end
            end
          end

          def cheapest_price
            thing = cheapest_thing
            thing.company? ? thing.value : (@game.par_prices(thing).map(&:price).min || 0) * 10
          end

          def setup_auction
            @bids.clear
            @first_player = current_entity

            start_idx = entity_index
            plist     = eligible_players
            size      = plist.size

            plist.each_index do |idx|
              @bids[plist[idx]] = -size + ((idx - start_idx) % size)
            end
          end

          def resolve_auction
            return if @bids.size > 1
            return if @bids.one? && highest_bid.negative?

            if @bids.any?
              player, price = @bids.to_a.flatten
              player.spend(price, @game.bank) if price.positive?
            else
              player = @first_player
              price  = 0
            end

            @log << "#{player.name} wins auction for #{@game.format_currency(price)}"
            @bids.clear

            @auction_winner = player
            @auction_open   = false
            @round.goto_entity!(player)
          end

          def can_afford?(_entity, _company)
            # Par costs the player nothing now; auction bidding is cash-gated elsewhere.
            true
          end

          def buy_company(player, company, listed_price)
            price = [listed_price, player.cash].min
            company.owner = player
            player.companies << company
            player.spend(price, @game.bank) if price.positive?
            @log << "#{player.name} buys #{company.name} for #{@game.format_currency(price)}"
            @companies.delete(company)
            @round.next_entity_index!
            setup_auction
          end
        end
      end
    end
  end
end
