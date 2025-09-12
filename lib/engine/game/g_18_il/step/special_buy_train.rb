# frozen_string_literal: true

require_relative '../../../step/special_buy_train'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialBuyTrain < Engine::Step::SpecialBuyTrain
          def buy_train_action(action, entity = nil, borrow_from: nil)
            @ic_bought_train = true if action.entity == @game.ic

            entity ||= action.entity
            train = action.train
            train.variant = action.variant
            price = action.price

            # Check if the train is actually buyable in the current situation
            if entity.cash < price && !entity.trains.empty?
              raise GameError, "#{entity.name} has #{@game.format_currency(entity.cash)} and "\
                               "cannot spend #{@game.format_currency(price)}"
            end
            raise GameError, 'Must pay face value' if must_pay_face_value?(train, entity, price)
            raise GameError, 'An entity cannot buy a train from itself' if train.owner == entity

            remaining = price - buying_power(entity)
            if remaining.positive? && president_may_contribute?(entity, action.shell)
              check_for_cheapest_train(train)

              raise GameError, 'Cannot buy for more than cost' if price > train.price

              player = entity.owner

              if player.cash < remaining
                raise GameError, 'Must sell shares before buying train' if sellable_shares?(player)

                try_take_loan(entity, price)
              else
                player.spend(remaining, entity)
                @log << "#{player.name} contributes #{@game.format_currency(remaining)}"
              end
            end

            @log << "#{entity.name} buys a #{train.name} train for "\
                    "#{@game.format_currency(price)} from #{train.owner.name}"

            @game.buy_train(entity, train, price)
            @game.phase.buying_train!(entity, train, train.owner)
            @game.emr_active = nil
          end
        end
      end
    end
  end
end
