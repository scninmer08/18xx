# frozen_string_literal: true

require_relative '../../g_18_il/step/buy_train'

module Engine
  module Game
    module G18IlSolo
      module Step
        class BuyTrain < G18IL::Step::BuyTrain
          def actions(entity)
            return [] if @game.last_set

            if entity.owner == @game.robot
              min_price = @depot.min_depot_price
              must_buy = must_buy_train?(entity)
              has_perm = owns_permanent_train?(entity)

              # When owning a permanent, only consider own treasury for obligation
              treasury_cash = entity.cash

              if has_perm && treasury_cash >= min_price && can_buy_train?(entity) && !already_owns_upcoming_train_type?(entity)
                return ['buy_train']
              end

              return [] if must_buy && @game.buying_power(entity) < min_price
              return [] if has_perm && treasury_cash < min_price

              if can_buy_train?(entity) && @game.buying_power(entity) >= min_price && !already_owns_upcoming_train_type?(entity)
                return ['buy_train']
              end

              return []
            end

            super
          end

          def owns_permanent_train?(entity)
            entity.trains.any? { |t| t.rusts_on.nil? && t.obsolete_on.nil? }
          end

          def family_names(train)
            names = [train.name]
            names.concat(train.variants.values.map { |v| v[:name] }.compact) if train.respond_to?(:variants) && train.variants
            names.uniq
          end

          def owns_family?(entity, ref_train)
            ref_set = family_names(ref_train)
            entity.trains.any? { |t| (family_names(t) & ref_set).any? }
          end

          def already_owns_upcoming_train_type?(entity)
            upcoming = @depot&.upcoming&.first
            return false unless upcoming

            owns_family?(entity, upcoming)
          end

          def buyable_trains(entity)
            if entity.owner == @game.robot
              trains = @depot.depot_trains.reject { |t| owns_family?(entity, t) }

              if trains.any? { |t| t.name == '6' }
                trains.reject! { |t| t.name == 'D' }
              end

              return trains
            end

            super
          end

          def train_variant_helper(train, entity)
            return super(train, entity) if !@game.subsidiary?(entity) && entity != @game.ic

            cash = @game.buying_power(entity)
            variants = train.variants.values
            priced = variants.map { |v| [v, v[:price] || train.price] }

            affordable = priced.select { |(_v, price)| price <= cash }
            chosen =
              if affordable.any?
                affordable.max_by { |(_v, price)| price }.first
              else
                priced.min_by { |(_v, price)| price }.first
              end

            [chosen]
          end

          def process_buy_train(action)
            entity = action.entity

            if @game.subsidiary?(entity)
              train = action.train
              variant_price =
                if action.variant
                  (train.variants[action.variant][:price] || train.price)
                else
                  train.price
                end

              price = action.price || variant_price
              need = price - entity.cash

              # IC only helps if subsidiary does not already own a permanent
              if !owns_permanent_train?(entity) && need.positive?
                ic = @game.ic
                take = [need, ic.cash].min
                if take.positive?
                  ic.spend(take, entity)
                  @log << "IC contributes #{@game.format_currency(take)} to #{entity.name} for train purchase"
                end
              end
            end

            super
          end

          def discountable_trains_allowed?(entity)
            return false if entity.owner == @game.robot

            super
          end
        end
      end
    end
  end
end
