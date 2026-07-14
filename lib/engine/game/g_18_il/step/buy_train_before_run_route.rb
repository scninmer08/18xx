# frozen_string_literal: true

require_relative '../../../step/buy_train'
require_relative '../../../game_error'

module Engine
  module Game
    module G18IL
      module Step
        class BuyTrainBeforeRunRoute < G18IL::Step::BuyTrain
          ACTIONS = %w[buy_train pass].freeze

          def actions(entity)
            return [] if @game.last_set
            return [] if @game.will_buy_other_train

            corporation = current_entity
            return [] if entity != corporation && entity != corporation&.owner
            return [] unless rush_delivery&.owner == corporation
            return [] if @round.premature_trains_bought.include?(corporation)
            return [] if corporation.cash < @depot.min_depot_price && corporation.trains.any?

            if entity.player?
              return [] unless president_may_contribute?(corporation)
              return %w[sell_shares] if sellable_shares?(entity)

              return []
            end

            actions = []
            actions << %w[buy_train sell_shares] if must_sell_shares?(corporation)
            actions << %w[buy_train] if can_buy_train?(corporation) || president_may_contribute?(corporation)
            actions << %w[pass] if !@acted && !@game.emr_active?

            actions.flatten
          end

          def must_buy_train?(_entity)
            false
          end

          def president_may_contribute?(entity, _shell = nil)
            ebuy_president_can_contribute?(entity)
          end

          def must_sell_shares?(corporation)
            return false if @game.will_buy_other_train
            return false if corporation.cash > @game.depot.min_depot_price

            must_issue_before_ebuy?(corporation)
          end

          def pass_description
            'Skip (Rush Delivery Train)'
          end

          def round_state
            {
              premature_trains_bought: [],
            }
          end

          def active_entities
            return [] unless rush_delivery&.owner == @round.current_operator

            [@round.current_operator]
          end

          def process_buy_train(action)
            raise GameError, 'Premature buys are only allowed from the Depot' unless action.train.from_depot?

            buy_train_action(action)

            @round.bought_trains << action.entity if @round.respond_to?(:bought_trains)
            @round.premature_trains_bought << action.entity

            company = @game.company_by_id('RD')
            @game.flip_private!(company)

            return if @game.pending_rusting_event

            pass!
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
             !entity.num_ipo_shares.zero?

            remaining = price - buying_power(entity)
            player = entity.owner
            if remaining.positive?
              check_for_cheapest_train(train)
              raise GameError, 'Cannot buy for more than cost' if price > train.price

              if player.cash < remaining
                raise GameError, 'Must sell shares before buying train' if sellable_shares?(player)

                try_take_loan(entity, price)
              else
                player.spend(remaining, entity)
                @log << "#{player.name} contributes #{@game.format_currency(remaining)}"
                if entity.loans.any?
                  @game.payoff_loan(entity)
                  try_take_loan(entity, price)
                end
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
            do_after_buy_train_action(action, entity)
          end

          def buyable_trains(entity)
            super - other_trains(entity)
          end

          def description
            "Use #{@game.company_by_id('RD').name} ability"
          end

          def can_buy_train?(entity)
            return false unless @round.premature_trains_bought.empty?

            super
          end

          def help
            "#{@game.company_by_id('RD')&.name} allows the corporation to buy one train from the Depot prior to running trains:"
          end

          def ability(entity)
            return if !rush_delivery || !entity || rush_delivery.owner != entity

            @game.abilities(rush_delivery, :train_buy)
          end

          def rush_delivery
            company = @game.company_by_id('RD')
            company unless @game.private_used?(company)
          end

          def do_after_buy_train_action(action, entity)
            action.train.buyable = false if entity == @game.ic && !action.train.rusts_on
            action.train.operated = false
          end
        end
      end
    end
  end
end
