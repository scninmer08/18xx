# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'

module Engine
  module Game
    module G1872
      module Step
        class BuySellParShares < Engine::Step::BuySellParShares
          def visible_corporations
            @game.sorted_corporations.reject do |corporation|
              corporation.type == :shell && !corporation.ipoed
            end
          end

          def allow_president_change?(corporation)
            !@game.sponsored_corporation?(corporation)
          end

          def can_buy?(entity, bundle)
            return false if bundle&.owner&.corporation? && bundle.owner != bundle.corporation

            super
          end

          def sell_shares(entity, bundle, swap: nil)
            raise GameError, "Cannot sell shares of #{bundle.corporation.name}" if !can_sell?(entity, bundle) && !swap

            @round.players_sold[bundle.owner][bundle.corporation] = :now
            @game.sell_shares_and_change_price(
              bundle,
              swap: swap,
              allow_president_change: allow_president_change?(bundle.corporation),
            )
          end

          def purchasable_companies(entity)
            return [] if bought? ||
              !available_cash(entity).positive? ||
              !@game.phase ||
              !@game.phase.status.include?('can_buy_companies_from_other_players') ||
              @game.turn == 1

            @game.purchasable_companies(entity)
          end
        end
      end
    end
  end
end
