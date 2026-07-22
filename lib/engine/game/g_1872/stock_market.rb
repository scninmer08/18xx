# frozen_string_literal: true

module Engine
  module Game
    module G1872
      class StockMarket < Engine::StockMarket
        def initialize(market, unlimited_types, multiple_buy_types: [], zigzag: nil, ledge_movement: nil, game: nil)
          @game = game
          super(market, unlimited_types, multiple_buy_types: multiple_buy_types, zigzag: zigzag, ledge_movement: ledge_movement)
        end

        def right(corporation, coordinates)
          if phase_limited_max_price?(corporation)
            up(corporation, coordinates)
          else
            super
          end
        end

        def phase_limited_max_price?(corporation)
          types = corporation&.share_price&.types
          return false unless types

          (@game.phase.name.to_i < 3 && types.include?(:max_price)) ||
            (@game.phase.name.to_i < 8 && types.include?(:max_price_1))
        end
      end
    end
  end
end
