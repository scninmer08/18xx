# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'
require_relative '../../../step/share_buying'
require_relative '../../../action/buy_shares'
require_relative '../../../action/par'

module Engine
  module Game
    module G18FLOOD
      module Step
        class BuySellParShares < Engine::Step::BuySellParShares
          def visible_corporations
            @game.nationals + @game.shells.select(&:floated?)
          end

          def can_gain?(entity, bundle, exchange: false)
            return if @game.national_corporation?(bundle.corporation)

            super
          end
        end
      end
    end
  end
end
