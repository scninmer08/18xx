# frozen_string_literal: true

require_relative '../../g_18_il/round/stock'

module Engine
  module Game
    module G18IlSolo
      module Round
        class Stock < G18IL::Round::Stock
          def finish_round
            corporations_to_move_price.sort.each do |corp|
              next unless corp.share_price
              next if corp == @game.ic

              old_price = corp.share_price

              sold_out_stock_movement(corp) if sold_out?(corp)
              price_drops =
                if (shares_in_pool = corp.num_market_shares).zero?
                  0
                else
                  shares_in_pool
                end
              price_drops.times { @game.stock_market.move_down(corp) }

              @game.log_share_price(corp, old_price)
            end
            @game.finish_stock_round
          end
        end
      end
    end
  end
end
