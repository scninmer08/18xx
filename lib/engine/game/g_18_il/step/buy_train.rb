# frozen_string_literal: true

require_relative '../../../step/buy_train'

module Engine
  module Game
    module G18IL
      module Step
        class BuyTrain < Engine::Step::BuyTrain
          def round_state
            { bought_trains: [] }
          end

          def actions(entity)
            return [] if @game.last_set
            # IC in receivership: once it has bought, it's done
            if entity == @game.ic && @game.ic_in_receivership? &&
               @round.respond_to?(:bought_trains) && @round.bought_trains.include?(entity)
              return []
            end

            return ['sell_shares'] if entity == current_entity&.player && !@game.other_train_pass
            return [] if entity != current_entity
            return %w[buy_train sell_shares] if must_sell_shares?(entity)
            return %w[buy_train] if must_buy_train?(entity)
            return %w[buy_train pass] if can_buy_train?(entity)

            []
          end

          def must_sell_shares?(corporation)
            return false if @game.other_train_pass
            return false if corporation.cash > @game.depot.min_depot_price
            return false unless must_buy_train?(corporation)
            return false unless @game.emergency_issuable_cash(corporation) < @game.depot.min_depot_price

            must_issue_before_ebuy?(corporation)
          end

          def must_buy_train?(entity)
            if entity == @game.ic
              # If IC already bought once this OR, the must-buy is lifted.
              return false if @round.respond_to?(:bought_trains) && @round.bought_trains.include?(entity)

              # Never force a buy if IC is already at its train limit
              return false if entity.trains.size >= @game.train_limit(entity)

              return false if @game.other_train_pass

              # Must buy iff there's at least one buyable train and IC can afford the min depot price
              return entity.cash >= @game.depot.min_depot_price && !buyable_trains(entity).empty?
            end

            # For everyone else: only must-buy if trainless
            entity.trains.empty?
          end

          def ebuy_president_can_contribute?(corporation)
            return false unless @game.emergency_issuable_cash(corporation) < @game.depot.min_depot_price
            return false if @game.other_train_pass

            !must_issue_before_ebuy?(corporation)
          end

          def must_issue_before_ebuy?(corporation)
            return false if @game.other_train_pass

            super
          end

          def president_may_contribute?(entity, _shell = nil)
            must_buy_train?(entity) && ebuy_president_can_contribute?(entity)
          end

          def description
            'Buy Trains'
          end

          def pass_description
            @acted ? 'Done (Trains)' : 'Skip (Trains)'
          end

          def pass!
            super
            return if @game.intro_game?

            company = @game.train_subsidy
            return if company.ability_uses.first == 99

            @log << "#{company.name} (#{@round.current_operator.name}) closes" unless company.closed?
            company.close!
          end

          def scrap_info(_train)
            ''
          end

          def scrap_button_text(_train)
            'Scrap'
          end

          def check_spend(action)
            return unless action.train.owned_by_corporation?

            min, max = spend_minmax(action.entity, action.train)
            return if (min..max).cover?(action.price)

            max = 0 if action.entity == @game.ic

            if max.zero? && !@game.class::EBUY_OTHER_VALUE
              raise GameError, "#{action.entity.name} may not buy a train from "\
                               'another corporation.'
            else
              raise GameError, "#{action.entity.name} may not spend "\
                               "#{@game.format_currency(action.price)} on "\
                               "#{action.train.owner.name}'s #{action.train.name} "\
                               'train; may only spend between '\
                               "#{@game.format_currency(min)} and "\
                               "#{@game.format_currency(max)}."
            end
          end

          def train_variant_helper(train, entity)
            return train.variants.values if entity != @game.ic || !@game.ic_in_receivership?

            [train.variants.values.min_by { |v| v[:price] || train.price }]
          end

          def buyable_trains(entity)
            return [@depot.min_depot_train].compact if entity == @game.ic && @game.ic_in_receivership?

            depot_trains = @depot.depot_trains
            depot_trains = [@depot.min_depot_train] if entity.cash < @depot.min_depot_price
            depot_trains = [] if @game.other_train_pass

            other_trains = other_trains(entity)
            other_trains.reject! { |t| t.owner == @game.ic } if @game.ic_in_receivership?
            other_trains = [] if entity.cash.zero? || @game.emr_active?

            return depot_trains if @game.last_set_pending

            depot_trains + other_trains
          end

          def process_sell_shares(action)
            raise GameError, 'Cannot sell shares when buying from another corporation' if @game.other_train_pass

            @game.emr_active = true
            return super unless action.entity.is_a?(Corporation)

            old_price = action.entity.share_price.price
            @game.sell_shares_and_change_price(action.bundle, movement: :down_share)
            new_price = action.entity.share_price.price
            @log << "#{action.entity.name}'s share price moves down from "\
                    "#{@game.format_currency(old_price)} to #{@game.format_currency(new_price)}"
          end

          def process_buy_train(action)
            check_spend(action)
            buy_train_action(action)
            @round.bought_trains << action.entity if @round.respond_to?(:bought_trains)
            @game.ic_owns_train! if action.entity == @game.ic

            if action.entity == @game.ic && @game.ic_in_receivership?
              pass!
              return
            end

            pass! unless can_buy_train?(action.entity)
          end

          def buy_train_action(action, entity = nil, borrow_from: nil)
            entity ||= action.entity
            train = action.train
            train.variant = action.variant
            price = action.price
            exchange = action.exchange

            if !buyable_exchangeable_train_variants(train, entity, exchange).include?(train.variant) ||
                !(@game.depot.available(entity).include?(train) || buyable_trains(entity).include?(train))
              raise GameError, "Not a buyable train: #{train.id}"
            end
            raise GameError, 'Must pay face value' if must_pay_face_value?(train, entity, price)
            raise GameError, 'An entity cannot buy a train from itself' if train.owner == entity
            raise GameError, 'Must issue shares before the president may contribute' if entity.cash < price &&
             !entity.num_ipo_shares.zero? && must_buy_train?(entity)

            remaining = price - buying_power(entity)
            player = entity.owner
            if remaining.positive? && must_buy_train?(entity)
              check_for_cheapest_train(train)
              raise GameError, 'Cannot buy for more than cost' if price > train.price
              if price > entity.cash && train != @depot.min_depot_train
                raise GameError, "#{entity.name} cannot spend #{@game.format_currency(price)}"
              end

              if player&.player?
                if player.cash >= remaining
                  player.spend(remaining, entity)
                  @log << "#{player.name} contributes #{@game.format_currency(remaining)}"
                else
                  if player.cash.positive?
                    amt = [player.cash, remaining].min
                    player.spend(amt, entity)
                    @log << "#{player.name} contributes #{@game.format_currency(amt)}"
                  end
                  raise GameError, 'Must sell shares before buying train' if sellable_shares?(player)

                  try_take_loan(entity, price)
                end
              else
                try_take_loan(entity, price)
              end
            end

            if exchange
              verb = "exchanges a #{exchange.name} for"
              @depot.reclaim_train(exchange)
            else
              verb = 'buys'
            end

            @log << "#{entity.name} #{verb} a #{train.name} train for "\
                    "#{@game.format_currency(price)} from #{train.owner.name}"

            @game.buy_train(entity, train, price)
            @game.phase.buying_train!(entity, train, train.owner)
            @game.emr_active = nil
          end

          def swap_sell(_player, _corporation, _bundle, _pool_share); end

          def try_take_loan(entity, price)
            remaining = price - buying_power(entity)

            @game.take_loan(entity, remaining) if remaining.positive?
          end

          def must_take_loan?(corporation)
            return false if sellable_shares?(corporation.owner)
            return false if @game.other_train_pass

            price = @game.depot.min_depot_price
            (@game.buying_power(corporation) + @game.buying_power(corporation.owner)) < price
          end

          def sellable_shares?(player)
            (@game.liquidity(player, emergency: true) - player.cash).positive?
          end
        end
      end
    end
  end
end
