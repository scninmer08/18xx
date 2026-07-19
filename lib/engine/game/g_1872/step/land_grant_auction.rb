# frozen_string_literal: true

require_relative '../../../action/bid'
require_relative '../../../step/base'
require_relative '../../../step/auctioner'

module Engine
  module Game
    module G1872
      module Step
        class LandGrantAuction < Engine::Step::Base
          include Engine::Step::Auctioner

          ACTIONS = %w[bid pass].freeze
          OPENING_BID = 0

          def setup
            setup_auction
            @auctioning = nil
            @active_bidders = []
            @auction_triggerer = nil
            @auctioned_ipo_row_indices = []
            @cycled_ipo_rows = false
          end

          def description
            return "Bid on #{@auctioning.name}" if @auctioning

            'Choose a Land Grant to Auction'
          end

          def pass_description
            return 'Pass' if @auctioning

            'Decline'
          end

          def available
            @game.land_grants
          end

          def show_companies
            true
          end

          def hide_corporations?
            true
          end

          def auctioning
            @auctioning
          end

          def auctioning_company
            @auctioning
          end

          def choice_available?(_entity)
            false
          end

          def choices_for_ipo_row(entity, company, _ipo_row_number)
            return [] unless can_start_auction?(entity, company)

            [[company.id, "Auction #{company.name}"]]
          end

          def actions(entity)
            return [] if available.empty?

            if @auctioning
              return ACTIONS if entity == current_entity

              return []
            end

            return [] if entity != current_entity || entity.passed?

            exposed_land_grants.empty? ? ['pass'] : %w[choose pass]
          end

          def active_entities
            return super unless @auctioning
            return [] if @active_bidders.empty?

            high_bid = highest_bid(@auctioning)
            return [@active_bidders.first] unless high_bid

            index = @active_bidders.index(high_bid.entity) || -1
            [@active_bidders[(index + 1) % @active_bidders.size]]
          end

          def process_choose(action)
            company = exposed_land_grants.find { |grant| grant.id == action.choice }
            raise GameError, 'That land grant is not exposed for auction' unless company
            raise GameError, "#{action.entity.name} cannot afford the opening bid" if action.entity.cash < OPENING_BID

            start_auction(action.entity, company)
          end

          def process_bid(action)
            raise GameError, 'No land grant is currently up for auction' unless @auctioning
            raise GameError, "Cannot bid on #{action.company.name}" unless action.company == @auctioning

            add_bid(action)
            remove_unable_bidders(action.entity)
            resolve_bids
          end

          def process_pass(action)
            if @auctioning
              pass_auction(action.entity)
              resolve_bids
              return
            end

            @log << "#{action.entity.name} declines to start a land grant auction"
            action.entity.pass!

            return finish_auction_round! if entities.all?(&:passed?) || exposed_land_grants.empty?

            next_entity!
          end

          def can_bid?(entity)
            @auctioning && entity == current_entity && max_bid(entity, @auctioning) >= min_bid(@auctioning)
          end

          def bid_entity
            @auctioning
          end

          def can_bid_company?(entity, company)
            @auctioning == company && can_bid?(entity)
          end

          def may_bid?(company)
            @auctioning == company
          end

          def may_purchase?(_company)
            false
          end

          def min_bid(company)
            return unless company
            return OPENING_BID unless highest_bid(company)

            highest_bid(company).price + min_increment
          end

          def max_bid(entity, _company)
            entity.cash
          end

          def max_place_bid(entity, company)
            max_bid(entity, company)
          end

          def committed_cash(player, _show_hidden = false)
            @bids.values.flatten.select { |bid| bid.entity == player }.sum(&:price)
          end

          private

          def can_start_auction?(entity, company)
            return false if @auctioning
            return false unless entity == current_entity
            return false if entity.passed?
            return false unless exposed_land_grants.include?(company)

            entity.cash >= OPENING_BID
          end

          def exposed_land_grants
            @game.ipo_rows.filter_map(&:first)
          end

          def start_auction(entity, company)
            @auctioning = company
            @auction_triggerer = entity
            @active_bidders = entities.rotate(entities.index(entity)).reject(&:bankrupt)
            @auctioned_ipo_row_indices << @game.ipo_rows.index { |row| row.first == company }
            @auctioned_ipo_row_indices.compact!
            @auctioned_ipo_row_indices.uniq!

            opening_bid = Engine::Action::Bid.new(entity, company: company, price: OPENING_BID)
            add_bid(opening_bid)
            @log << "#{entity.name} puts #{company.name} up for auction"

            remove_unable_bidders(entity)
            resolve_bids
          end

          def add_bid(bid)
            entity = bid.entity
            company = bid.company
            price = bid.price
            min = min_bid(company)

            raise GameError, "Minimum bid is #{@game.format_currency(min)} for #{company.name}" if price < min
            raise GameError, 'Bid must be a multiple of $5' if (price % min_increment).nonzero?
            raise GameError, "#{entity.name} cannot afford #{@game.format_currency(price)}" if price > max_bid(entity, company)

            @bids[company].reject! { |existing_bid| existing_bid.entity == entity }
            @bids[company] << bid
            @log << "#{entity.name} bids #{@game.format_currency(price)} for #{company.name}"
          end

          def remove_unable_bidders(current_bidder)
            min = min_bid(@auctioning)
            @active_bidders.dup.each do |player|
              next if player == current_bidder
              next if max_bid(player, @auctioning) >= min

              @log << "#{player.name} cannot bid #{@game.format_currency(min)} and is out of the auction for "\
                      "#{@auctioning.name}"
              @active_bidders.delete(player)
            end
          end

          def pass_auction(entity)
            @log << "#{entity.name} declines to bid on #{@auctioning.name}"
            @active_bidders.delete(entity)
          end

          def resolve_bids
            return unless @auctioning
            return if @active_bidders.size > 1

            winner = highest_bid(@auctioning)
            company = @auctioning

            if winner
              win_bid(winner, company)
            else
              @log << "No one bids on #{company.name}"
            end

            @bids.delete(company)
            @active_bidders.clear
            @auctioning = nil
            after_auction
          end

          def win_bid(winning_bid, company)
            player = winning_bid.entity
            price = winning_bid.price

            player.spend(price, @game.bank) if price.positive?
            company.owner = player
            player.companies << company
            @game.remove_land_grant(company)
            @log << "#{player.name} wins #{company.name} for #{@game.format_currency(price)}"
          end

          def after_auction
            return finish_auction_round! if exposed_land_grants.empty?

            entities.each(&:unpass!)
            @round.goto_entity!(@auction_triggerer)
            next_entity!
            @auction_triggerer = nil
          end

          def finish_auction_round!
            unless @cycled_ipo_rows
              @game.cycle_unauctioned_land_grant_rows(@auctioned_ipo_row_indices)
              @cycled_ipo_rows = true
            end

            pass!
          end

          def next_entity!
            skipped = 0
            loop do
              @round.next_entity_index!
              entity = entities[entity_index]
              return unless entity
              return if !entity.passed? && (exposed_land_grants.empty? || entity.cash >= OPENING_BID)

              process_pass(Engine::Action::Pass.new(entity))
              skipped += 1
              return finish_auction_round! if skipped >= entities.size
            end
          end
        end
      end
    end
  end
end
