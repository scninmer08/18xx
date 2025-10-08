# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Corporations
        TOKEN_COST  = 80
        SHELL_COUNT = 9
        CORPORATIONS = [
          {
            float_percent: 100,
            sym: 'N1',
            name: 'National 1',
            logo: '18_flood/N1',
            simple_logo: '18_flood/N1',
            shares: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            tokens: [0, TOKEN_COST],
            coordinates: 'J7',
            color: '#4682B4',
            type: :national,
            max_ownership_percent: 100,
            always_market_price: true,
          },
          {
            float_percent: 100,
            sym: 'N2',
            name: 'National 2',
            logo: '18_flood/N2',
            simple_logo: '18_flood/N2',
            shares: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            tokens: [0, TOKEN_COST],
            coordinates: 'D25',
            color: '#2600AA',
            type: :national,
            max_ownership_percent: 100,
            always_market_price: true,
          },
          {
            float_percent: 100,
            sym: 'N3',
            name: 'National 3',
            logo: '18_flood/N3',
            simple_logo: '18_glood/N3',
            shares: [10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
            tokens: [0, TOKEN_COST],
            coordinates: 'P25',
            color: '#F40006',
            max_ownership_percent: 100,
            always_market_price: true,
            type: :national,
          },
        ].freeze

        def game_corporations
          base   = self.class::CORPORATIONS.reject { |c| (c[:type] || c['type'])&.to_sym == :shell }
          shells = build_shells(SHELL_COUNT)
          # Sort by numeric portion of :sym (e.g., "S10" -> 10)
          shells.sort_by! { |h| h[:sym].delete_prefix('S').to_i }
          base + shells
        end

        def build_shells(count)
          (1..count).map do |i|
            {
              float_percent: 50,
              sym: "S#{i}",
              name: "Shell #{i}",
              logo: "18_flood/#{i}",
              simple_logo: "18_flood/#{i}",
              shares: [50, 10, 10, 10, 10, 10],
              tokens: [0],
              color: '#000000',
              max_ownership_percent: 100,
              always_market_price: true,
              type: :shell,
            }
          end
        end
      end
    end
  end
end
