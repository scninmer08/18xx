# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Market
        MARKET_SHARE_LIMIT = 100
        MARKET = [
          %w[
            10
            20
            30
            40
            50
            60
            70
            80p
            90
            100p
            110
            120p
            130
            140p
            150
            160p
            170
            180
            190
            200
            210
            220
            230
            240
            250
            260
            270
            280
            290
            300
          ],
        ].freeze

        # STOCKMARKET_COLORS = Base::STOCKMARKET_COLORS.merge(
        #   par: :yellow,
        #   repar: :red,
        # ).freeze

        # MARKET_TEXT = {
        #   par: 'Par value',
        #   close: 'Corporation closes',
        #   endgame: 'End game trigger',
        #   repar: 'Cannot convert',
        # }.freeze

        def price_movement_chart
          [
            ['Action', 'Share Price Change'],
            ['Dividend < stock price', '0'],
            ['Dividend ≥ stock price', '1 →'],
            # ['Dividend ≥ 2X stock price', '2 →'],
          ]
        end
      end
    end
  end
end
