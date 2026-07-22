# frozen_string_literal: true

require_relative '../../../step/company_pending_par'

module Engine
  module Game
    module G1872
      module Step
        class CompanyPendingPar < Engine::Step::CompanyPendingPar
          def process_par(action)
            unless get_par_prices(action.entity, action.corporation).include?(action.share_price)
              raise GameError, 'That par price is unavailable'
            end

            super
          end

          def get_par_prices(_entity, _corporation)
            @game.stock_market.par_prices.reject { |price| @game.par_price_gated_until_phase_3?(price) }
          end
        end
      end
    end
  end
end
