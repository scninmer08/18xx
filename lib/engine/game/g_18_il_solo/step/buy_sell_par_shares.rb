# frozen_string_literal: true

require_relative '../../g_18_il/step/base_buy_sell_par_shares'

module Engine
  module Game
    module G18IlSolo
      module Step
        class BuySellParShares < G18IL::Step::BaseBuySellParShares
          def actions(entity)
            return [] if entity == @game.robot

            super
          end

          def ic
            @game.ic
          end

          def allow_president_change?(corporation)
            return false if corporation.owner == @game.robot

            super
          end

          def log_skip(entity)
            return if entity == @game.robot

            super
          end

          def buyable_shares(entity, corporation)
            shares = super
            return shares unless corporation.owner == @game.robot

            shares.reject(&:president)
          end

          def can_gain?(entity, bundle, exchange: false)
            return false unless super
            return true if !entity.player? || entity == @game.robot

            corp = bundle.corporation
            return true if corp != @game.ic && !@game.subsidiary?(corp)

            robot_pct  = @game.robot.percent_of(corp)
            player_pct = entity.percent_of(corp)
            new_pct    = player_pct + bundle.common_percent

            new_pct <= robot_pct
          end
        end
      end
    end
  end
end
