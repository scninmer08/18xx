# frozen_string_literal: true

module Engine
  module Game
    module G1872
      module Entities
        SHELL_COUNT = 24

        COMPANIES = [
          # {
          #   name: 'Butterfield Overland Despatch',
          #   sym: 'BOD',
          #   value: 20,
          #   revenue: 5,
          #   desc: 'No special ability.',
          #   color: nil,
          # },
          # {
          #   name: 'Big Creek Land Company',
          #   sym: 'BCLC',
          #   value: 40,
          #   revenue: 10,
          #   desc: 'No special ability.',
          #   color: nil,
          # },
          # {
          #   name: 'Palmer–Greenwood Survey',
          #   sym: 'PGS',
          #   value: 60,
          #   revenue: 15,
          #   desc: 'Includes one yellow gentle-curve (#8) tile. An owning corporation may lay it as a normal track '\
          #         'action, following all normal track-laying rules. Closes after use.',
          #   color: nil,
          # },
          # {
          #   name: 'Burnham Shops',
          #   sym: 'BS',
          #   value: 80,
          #   revenue: 20,
          #   desc: 'No special ability.',
          #   color: nil,
          # },
          # {
          #   name: 'Crédit Mobilier of America',
          #   sym: 'CMA',
          #   value: 100,
          #   revenue: 10,
          #   desc: 'Once during each operating turn, an owning corporation may pay $20 to take one additional track '\
          #         'action. All normal track-laying costs and restrictions apply.',
          #   color: nil,
          # },
          # {
          #   name: 'Dodge City Town Company',
          #   sym: 'DCTC',
          #   value: 120,
          #   revenue: 0,
          #   desc: 'The purchasing player immediately receives one 10% share of the Atchison, Topeka & Santa Fe '\
          #         'Railway (ATSF) from its treasury. Receiving the share does not close this company.',
          #   abilities: [{ type: 'shares', shares: 'ATSF_1' }],
          #   color: nil,
          # },
          # {
          #   name: 'Leavenworth, Pawnee & Western Railroad',
          #   sym: 'LP&W',
          #   value: 200,
          #   revenue: 30,
          #   desc: 'The purchasing player receives the 20% president’s certificate of Kansas Pacific (KP) from its treasury and '\
          #         'immediately sets KP’s par price. Closes when KP purchases its first train. A corporation may not purchase '\
          #         'this company.',
          #   abilities: [
          #     { type: 'close', when: 'bought_train', corporation: 'KP' },
          #     { type: 'close', on_phase: 'never' },
          #     { type: 'no_buy' },
          #     { type: 'shares', shares: 'KP_0' },
          #   ],
          #   color: nil,
          # },
        ].freeze
        CORPORATIONS = [
          {
            sym: 'ATSF',
            name: 'Atchison, Topeka & Santa Fe Railway',
            logo: '1872/ATSF',
            simple_logo: '1872/ATSF.alt',
            coordinates: 'K23',
            tokens: [0],
            color: '#000e4b',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'CB&Q',
            name: 'Chicago, Burlington & Quincy Railroad',
            logo: '1872/CBQ',
            simple_logo: '1872/CBQ.alt',
            coordinates: 'C35',
            tokens: [0],
            color: '#8C8C7E',
            text_color: 'black',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'C&NW',
            name: 'Chicago & North Western Railway',
            logo: '1872/CNW',
            simple_logo: '1872/CNW.alt',
            coordinates: 'B38',
            tokens: [0],
            color: '#E2E071',
            text_color: 'black',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'KATY',
            name: 'Missouri–Kansas–Texas Railroad',
            logo: '1872/KATY',
            simple_logo: '1872/KATY.alt',
            coordinates: 'H42',
            tokens: [0],
            color: '#006521',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'KP',
            name: 'Kansas Pacific Railway',
            logo: '1872/KP',
            simple_logo: '1872/KP.alt',
            coordinates: 'G41',
            tokens: [0],
            color: '#93bcdc',
            text_color: 'black',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'MP',
            name: 'Missouri Pacific Railroad',
            logo: '1872/MP',
            simple_logo: '1872/MP.alt',
            coordinates: 'F40',
            tokens: [0],
            color: '#c62024',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'RI',
            name: 'Chicago, Rock Island and Pacific Railway',
            logo: '1872/RI',
            simple_logo: '1872/RI.alt',
            coordinates: 'K33',
            tokens: [0],
            color: '#881319',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'UP',
            name: 'Union Pacific Railroad',
            logo: '1872/UP',
            simple_logo: '1872/UP.alt',
            coordinates: 'F36',
            tokens: [0],
            color: '#006D9C',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
        ].concat(
          (1..SHELL_COUNT).map do |number|
            id = format('S%02d', number)
            {
              sym: id,
              name: "Unassigned Shell #{number}",
              logo: "1872/shells/#{id}",
              simple_logo: "1872/shells/#{id}",
              coordinates: nil,
              tokens: [0],
              color: '#000000',
              type: :shell,
              float_percent: 20,
              always_market_price: true,
            }
          end,
        ).freeze
      end
    end
  end
end
