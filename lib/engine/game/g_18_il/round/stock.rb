# frozen_string_literal: true

require_relative '../../../round/stock'

module Engine
  module Game
    module G18IL
      module Round
        class Stock < Engine::Round::Stock
          def finish_round
            corporations_to_move_price.sort.each do |corp|
              next unless corp.share_price

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

          def sold_out_stock_movement(corp)
            @game.stock_market.move_up(corp)
            @game.stock_market.move_up(corp) if corp.total_shares == 10
          end

          def sold_out?(corporation)
            corporation.total_shares > 2 && (corporation.player_share_holders.values.sum +
            corporation.corporate_share_holders.values.sum) >= 100
          end
        end
      end
    end
  end
end
