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
            return [] if entity != current_entity && entity != current_entity.owner

            if entity == @game.ic && @game.ic_in_receivership? &&
              @round.respond_to?(:bought_trains) && @round.bought_trains.include?(entity)
              return []
            end

            if entity.player?
              return [] if @game.will_buy_other_train
              return [] unless president_may_contribute?(current_entity)
              return %w[sell_shares] if sellable_shares?(entity)

              return []
            end

            return %w[buy_train sell_shares] if must_sell_shares?(entity)
            return %w[buy_train] if must_buy_train?(entity)
            return %w[buy_train pass] if can_buy_train?(entity)

            []
          end

          def must_sell_shares?(corporation)
            return false if @game.will_buy_other_train
            return false if corporation.cash > @game.depot.min_depot_price
            return false unless must_buy_train?(corporation)

            must_issue_before_ebuy?(corporation)
          end

          def must_buy_train?(entity)
            if entity == @game.ic
              # Lift the must-buy requirement if IC already bought once this OR.
              return false if @round.respond_to?(:bought_trains) && @round.bought_trains.include?(entity)

              return false if @game.will_buy_other_train

              return true if receivership_forced_depot_buy?(entity)
              return true if receivership_forced_d_upgrade?(entity)

              # IC must acquire the cheapest bank train if it has no train during its train-buying step.
              return entity.trains.empty? && !@game.depot.depot_trains.empty?
            end

            # Other corporations must buy only when trainless.
            entity.trains.empty?
          end

          def ebuy_president_can_contribute?(corporation)
            return false unless @game.emergency_issuable_cash(corporation) < @game.depot.min_depot_price
            return false if @game.will_buy_other_train

            !must_issue_before_ebuy?(corporation)
          end

          def must_issue_before_ebuy?(corporation)
            return false if @game.will_buy_other_train

            super
          end

          def president_may_contribute?(entity, _shell = nil)
            return false if entity == @game.ic

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

            company = @game.company_by_id('TS')
            ability = company.all_abilities.find { |item| item.type == :train_discount }
            return unless ability&.used?

            @game.flip_private!(company)
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

          def buyable_trains(entity)
            min_variant_price = lambda do |t|
              prices = [t.price]
              prices.concat(t.variants.values.map { |v| v[:price] })
              prices.min
            end

            return [cheapest_depot_train].compact if receivership_forced_depot_buy?(entity)
            return [] if receivership_forced_d_upgrade?(entity)

            depot_trains = @depot.depot_trains.dup
            depot_trains.select! do |t|
              min_variant_price.call(t) <= entity.cash
            end

            depot_trains << @depot.min_depot_train unless depot_trains.include?(@depot.min_depot_train)

            if depot_trains.any? { |t| t.name == '8' } && ((d = depot_trains.find { |t| t.name == 'D' }) && entity.cash < d.price)
              depot_trains.delete(d)
            end

            other_trains = @game.can_buy_train_from_others? ? other_trains(entity) : []
            other_trains.reject! { |t| @game.operated_this_round?(t.owner) && t.owner.trains.size == 1 } if @game.last_set_pending
            return depot_trains if receivership_ic?(entity)

            other_trains.reject! { |t| t.owner == @game.ic } if @game.ic_in_receivership?
            if entity == @game.ic && entity.trains.empty?
              other_trains.select! { |t| t.price <= entity.cash }
              return [@depot.min_depot_train, *other_trains].compact
            end

            other_trains = [] if @game.emr_active?
            return other_trains if @game.will_buy_other_train

            depot_trains + other_trains
          end

          def discountable_trains_allowed?(entity)
            return false if receivership_forced_depot_buy?(entity)

            super
          end

          def train_variant_helper(train, entity)
            variants = train.variants.values
            return variants if train.owned_by_corporation?
            return variants if train.variants.key?('0+3C')

            cash = entity.cash
            priced = variants.map { |v| [v, (v[:price] || train.price)] }

            affordable = priced.select { |_v, p| p <= cash }
            return affordable.map(&:first) if affordable.any?

            [priced.min_by { |_v, p| p }.first]
          end

          def process_sell_shares(action)
            raise GameError, 'Cannot sell shares when buying from another corporation' if @game.will_buy_other_train

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

            return if @game.pending_rusting_event

            pass! if (action.entity == @game.ic && @game.ic_in_receivership?) ||
                      !can_buy_train?(action.entity)
          end

          def buy_train_action(action, entity = nil, borrow_from: nil)
            entity ||= action.entity
            train = action.train
            train.variant = action.variant
            price = action.price
            exchange = action.exchange

            if receivership_ic?(entity) && train.owned_by_corporation?
              raise GameError, "#{entity.name} may only buy trains from the Depot while in receivership"
            end

            raise GameError, 'Must pay face value' if entity == @game.ic && train.owned_by_corporation? && price != train.price

            if !buyable_exchangeable_train_variants(train, entity, exchange).include?(train.variant) ||
                !(@game.depot.available(entity).include?(train) || buyable_trains(entity).include?(train))
              raise GameError, "Not a buyable train: #{train.id}"
            end
            raise GameError, 'Must pay face value' if must_pay_face_value?(train, entity, price)
            raise GameError, 'An entity cannot buy a train from itself' if train.owner == entity

            check_receivership_forced_train!(entity, train, price, exchange)

            if ic_trainless_bank_train?(entity, train, price, exchange)
              buy_train_for_trainless_ic(entity, train, price)
              return
            end

            remaining = price - buying_power(entity)
            player = entity.owner
            if remaining.positive? && must_buy_train?(entity)
              check_for_cheapest_train(train)
              raise GameError, 'Cannot buy for more than cost' if price > train.price
              if price > entity.cash && train != @depot.min_depot_train
                raise GameError, "#{entity.name} cannot spend #{@game.format_currency(price)}"
              end
              raise GameError, 'Must issue shares before the president may contribute' if entity.cash < price &&
                !entity.num_ipo_shares.zero?

              if player&.player?
                if player.cash >= remaining
                  player.spend(remaining, entity)
                  @log << "#{player.name} contributes #{@game.format_currency(remaining)}"
                  repay_loan_and_refund_train_shortfall(entity, price)
                else
                  if player.cash.positive?
                    amt = [player.cash, remaining].min
                    player.spend(amt, entity)
                    @log << "#{player.name} contributes #{@game.format_currency(amt)}"
                    repay_loan_and_refund_train_shortfall(entity, price)
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
            do_after_buy_train_action(action, entity)
          end

          def do_after_buy_train_action(_action, _entity); end

          def check_receivership_forced_train!(entity, train, price, exchange)
            if receivership_forced_depot_buy?(entity)
              return if train == cheapest_depot_train && !exchange && price == train.price

              raise GameError, "#{entity.name} must buy the cheapest available train from the Depot"
            end

            return unless receivership_forced_d_upgrade?(entity)
            return if forced_d_upgrade_options(entity).any? do |owned_train, depot_train, _variant, upgrade_price|
              owned_train == exchange && depot_train == train && upgrade_price == price
            end

            raise GameError, "#{entity.name} must upgrade to a D train"
          end

          def receivership_forced_depot_buy?(entity)
            entity == @game.ic &&
              @game.ic_in_receivership? &&
              room?(entity) &&
              cheapest_depot_train &&
              entity.cash >= cheapest_depot_train.price
          end

          def receivership_forced_d_upgrade?(entity)
            entity == @game.ic &&
              @game.ic_in_receivership? &&
              !receivership_forced_depot_buy?(entity) &&
              forced_d_upgrade_options(entity).any?
          end

          def forced_d_upgrade_options(entity)
            return [] unless entity == @game.ic

            @game.discountable_trains_for(entity).select do |_owned_train, depot_train, _variant, price|
              depot_train.name == 'D' && price <= entity.cash
            end
          end

          def cheapest_depot_train
            @depot.min_depot_train
          end

          def receivership_ic?(entity)
            entity == @game.ic && @game.ic_in_receivership?
          end

          def ic_trainless_bank_train?(entity, train, price, exchange)
            entity == @game.ic &&
              entity.trains.empty? &&
              price > entity.cash &&
              train == @depot.min_depot_train &&
              train.from_depot? &&
              !exchange
          end

          def buy_train_for_trainless_ic(entity, train, price)
            shortfall = price - entity.cash
            @game.take_loan(entity, shortfall) if shortfall.positive?

            @log << "#{entity.name} buys a #{train.name} train for "\
                    "#{@game.format_currency(price)} from #{train.owner.name}"

            @game.buy_train(entity, train, price)
            @game.phase.buying_train!(entity, train, train.owner)
            @game.emr_active = nil
            do_after_buy_train_action(nil, entity)
          end

          def swap_sell(_player, _corporation, _bundle, _pool_share); end

          def try_take_loan(entity, price)
            remaining = price - buying_power(entity)

            @game.take_loan(entity, remaining) if remaining.positive?
          end

          def repay_loan_and_refund_train_shortfall(entity, price)
            return if entity.loans.empty?

            @game.payoff_loan(entity)
            try_take_loan(entity, price)
          end

          def must_take_loan?(corporation)
            owner = corporation.owner
            return false if sellable_shares?(owner)
            return false if @game.will_buy_other_train

            price = @game.depot.min_depot_price
            owner_buying_power = owner&.player? ? @game.buying_power(owner) : 0
            (@game.buying_power(corporation) + owner_buying_power) < price
          end

          def sellable_shares?(player)
            return false unless player&.player?

            (@game.liquidity(player, emergency: true) - player.cash).positive?
          end
        end
      end
    end
  end
end
