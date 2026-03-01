# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Market
        MARKET_SHARE_LIMIT = 100
        MARKET = [
          %w[
            0c
            10#r
            20#r
            30#r
            40p
            50
            60p
            67
            74
            80p
            85
            90
            95
            100p
            105
            110
            115
            120p
            125
            130
            135
            140
            145
            150
            158
            166
            174
            182
            190
            200
            210
            220
            230
            240
            250
            262
            274
            286
            300
            314
            330
            346
            364
            382
            400
            420
            440
            460
            480
            500e
          ],
        ].freeze

        STOCKMARKET_COLORS = Base::STOCKMARKET_COLORS.merge(
          par: :yellow,
          #repar: :red,
        ).freeze

        MARKET_TEXT = {
          par: 'Par value',
          close: 'Corporation closes',
          endgame: 'End game trigger',
          #repar: 'Cannot convert',
        }.freeze

        def price_movement_chart
          [
            ['Action', 'Share Price Change'],
            ['Dividend = 0', '1 ←'],
            ['Dividend < 1/2 stock price', '1 ⤪'],
            ['Dividend ≥ 1/2 stock price but < stock price', '1 ⤨'],
            ['Dividend ≥ stock price', '1 →'],
            ['Dividend ≥ 2X stock price', '2 →'],
            ['Dividend ≥ 3X stock price', '3 →'],
            ['Voluntary Issue', 'Full Amount, then 1 ←'],
            ['Emergency Issue', 'Half Amount, then ⤪ for each'],
            ['Corporation is sold out at end of an SR', '1 ⤨ (5-share) or 1 → (10-share)'],
            ['Corporation has any shares in the Market at end of an SR', '⤪ for each'],
          ]
        end
      end
    end
  end
end
