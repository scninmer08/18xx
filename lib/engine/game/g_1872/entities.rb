# frozen_string_literal: true

module Engine
  module Game
    module G1872
      module Entities
        BRANCH_COUNT = 24

        COMPANIES = [
          {
            name: 'Butterfield Overland Despatch',
            sym: 'BOD',
            value: 20,
            revenue: 5,
            desc: 'No special ability.',
            abilities: [
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
          {
            name: 'Big Creek Land Company',
            sym: 'BCLC',
            value: 40,
            revenue: 10,
            desc: 'This company reserves one token slot in Hays (H26). When laying a yellow tile in Hays, the owning '\
                  'corporation may use this ability to lay either the normal #57 tile or the special #X00 tile. '\
                  'Whether used while laying Hays or after Hays already has a tile, the owning corporation immediately '\
                  'creates and places a new token in the Hays reservation. This company then closes.',
            abilities: [
              { type: 'reservation', hex: 'H26', city: 0 },
              {
                type: 'tile_lay',
                hexes: ['H26'],
                tiles: %w[57 X00],
                when: 'track',
                owner_type: 'corporation',
                count: 1,
                consume_tile_lay: true,
                special: true,
              },
              {
                type: 'token',
                hexes: ['H26'],
                price: 0,
                connected: false,
                owner_type: 'corporation',
                count: 1,
                check_tokenable: false,
              },
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
          {
            name: 'Palmer–Greenwood Survey',
            sym: 'PGS',
            value: 60,
            revenue: 15,
            desc: 'Includes one yellow gentle-curve (#8) tile. The owning corporation may lay it as a normal track '\
                  'action, following all normal track-laying rules. This company closes after the tile is placed.',
            abilities: [
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
          {
            name: 'Burnham Shops',
            sym: 'BS',
            value: 80,
            revenue: 20,
            desc: 'This company reserves one token slot in Denver’s southeastern entrance. The owning corporation may '\
                  'place a token there as its token action if it has a route to Denver. This company closes after use.',
            abilities: [
              { type: 'reservation', hex: 'F4', city: 3 },
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
          {
            name: 'Crédit Mobilier of America',
            sym: 'CMA',
            value: 100,
            revenue: 10,
            desc: 'Once during each operating turn, the owning corporation may pay $20 to take one additional track '\
                  'action. All normal track-laying costs and restrictions apply.',
            abilities: [
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
          {
            name: 'Dodge City Town Company',
            sym: 'DCTC',
            value: 120,
            revenue: 20,
            desc: 'The owning player may exchange this private company for a 10% share of ATSF from its treasury.',
            abilities: [
              {
                type: 'exchange',
                corporations: ['ATSF'],
                owner_type: 'player',
                when: 'stock_round',
                from: 'ipo',
              },
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
          {
            name: 'Leavenworth, Pawnee & Western Railroad',
            sym: 'LPW',
            value: 200,
            revenue: 30,
            desc: 'The purchasing player receives the 20% president’s certificate of KP from its treasury and immediately sets '\
                  'KP’s par price. The company closes when KP purchases its first train. A corporation may not purchase this '\
                  'company.',
            abilities: [
              { type: 'close', when: 'bought_train', corporation: 'KP' },
              { type: 'close', on_phase: 'never' },
              { type: 'no_buy' },
              { type: 'shares', shares: 'KP_0' },
              { type: 'close', owner_type: 'player', on_phase: '5' },
              { type: 'revenue_change', revenue: 0, on_phase: '5' },
            ],
            color: nil,
          },
        ].freeze
        CORPORATIONS = [
          {
            sym: 'ATSF',
            name: 'Atchison, Topeka & Santa Fe Railway',
            logo: '1872/ATSF',
            simple_logo: '1872/ATSF.alt',
            coordinates: 'H38',
            tokens: [0],
            color: '#000e4b',
            type: :parent,
            float_percent: 50,
            always_market_price: true,
          },
          {
            sym: 'CBQ',
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
            sym: 'CNW',
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
            coordinates: 'J36',
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
            coordinates: 'H42',
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
          (1..BRANCH_COUNT).map do |number|
            id = format('S%02d', number)
            {
              sym: id,
              name: "Branch #{number}",
              logo: "1872/branches/#{id}",
              simple_logo: "1872/branches/#{id}",
              coordinates: nil,
              tokens: [0],
              color: '#000000',
              type: :branch,
              float_percent: 20,
              always_market_price: true,
            }
          end,
        ).freeze
      end
    end
  end
end
