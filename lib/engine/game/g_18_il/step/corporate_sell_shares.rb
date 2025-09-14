# frozen_string_literal: true

require_relative '../../../step/corporate_sell_shares'
require_relative 'buy_train'

module Engine
  module Game
    module G18IL
      module Step
        class CorporateSellShares < Engine::Step::BuyTrain
          def description
            'Emergency Sell Shares'
          end

          def setup
            @game.will_buy_other_train = nil
            @acted = nil
            super
          end

          def actions(entity)
            return [] unless entity == current_entity
            return [] if entity.cash > @game.depot.min_depot_price
            return [] unless entity.shares != entity.ipo_shares
            return [] unless entity.trains.empty?
            return [] unless can_sell_any?(entity)

            actions = []
            actions << 'corporate_sell_shares' if entity.cash < @game.depot.min_depot_price && entity.trains.empty?
            actions << 'pass' if !other_trains(entity).empty? && !@acted && !entity.cash.zero?

            actions
          end

          def bought?(entity, corporation); end

          def log_skip(entity); end

          def pass_description
            'Pass'
          end

          def help
            str = []
            if @game.rush_delivery&.owner == @round.current_operator
              str << "#{@game.rush_delivery&.name} allows the corporation to buy one train from the Depot "\
                     'prior to running trains.'
            end
            str << 'If emergency money raising, corporation must first sell shares of IC.'
            str << 'Pass if buying a train from another corporation:'
            str
          end

          def process_pass(entity)
            # will_buy_other_train flag is set to true if corporation indicates that they are buying
            # from another corporation and will not EMR for a train
            @game.will_buy_other_train = true
            super
          end

          def process_corporate_sell_shares(action)
            @game.emr_active = true
            sell_shares(action.entity, action.bundle)
          end

          def can_sell_any?(entity)
            entity.corporate_shares.select { |share| can_sell?(entity, share.to_bundle) }.any?
          end

          def can_sell?(entity, bundle)
            bundle.shares.each { |s| return false if @game.corporate_buy&.shares&.include?(s) }
            return unless bundle
            return false if entity != bundle.owner

            entity != bundle.corporation
          end

          def sell_shares(entity, bundle)
            raise GameError, "Cannot sell shares of #{bundle.corporation.name}" unless can_sell?(entity, bundle)

            @acted = true
            @game.sell_shares_and_change_price(bundle)
          end

          def source_list(entity)
            entity.corporate_shares.map(&:corporation).compact.uniq
          end
        end
      end
    end
  end
end
