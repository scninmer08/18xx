# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'

module Engine
  module Game
    module G18IL
      module Companies
        MINES = %w[D9 D17 E6 E14 E16 F5 F13 F21 G22 H11].freeze

        def game_companies
          companies = [
            {
              name: 'Peoria and Bureau Valley Railroad',
              sym: 'P&BV',
              value: 10,
              revenue: 0,
              corporation: 'P&BV',
              color: '#4682B4',
              text_color: 'white',
              meta: { type: :concession, share_count: 2 },
            },
            {
              name: 'Northern Cross Railroad',
              sym: 'NC',
              value: 10,
              revenue: 0,
              corporation: 'NC',
              color: '#2600AA',
              text_color: 'white',
              meta: { type: :concession, share_count: 2 },
            },
            {
              name: 'Galena and Chicago Union Railroad',
              sym: 'G&CU',
              value: 10,
              revenue: 0,
              corporation: 'G&CU',
              color: '#F40006',
              text_color: 'white',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Rock Island Line',
              sym: 'RI',
              value: 10,
              revenue: 0,
              corporation: 'RI',
              color: '#FF9007',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Chicago and Alton Railroad',
              sym: 'C&A',
              value: 10,
              revenue: 0,
              corporation: 'C&A',
              color: '#45DF00',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Vandalia Railroad',
              sym: 'V',
              value: 10,
              revenue: 0,
              corporation: 'V',
              color: '#FFFD44',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Wabash Railroad',
              sym: 'WAB',
              value: 10,
              revenue: 0,
              corporation: 'WAB',
              color: '#ABABAB',
              text_color: 'black',
              meta: { type: :concession, share_count: 10 },
            },
            {
              name: 'Chicago and Eastern Illinois Railroad',
              sym: 'C&EI',
              value: 10,
              revenue: 0,
              corporation: 'C&EI',
              color: '#740013',
              text_color: 'white',
              meta: { type: :concession, share_count: 10 },
            },
            {
              name: "IC President's Share",
              sym: 'ICP',
              value: 0,
              revenue: 0,
              desc: "President's Share (20%) of IC",
              corporation: 'IC',
              color: '#006A14',
              text_color: 'white',
              meta: { type: :presidents_share },
            },
            {
              name: 'IC Share',
              sym: 'IC1',
              value: 0,
              revenue: 0,
              desc: 'Ordinary Share (10%) of IC',
              corporation: 'IC',
              color: '#006A14',
              text_color: 'white',
              meta: { type: :share },
            },
            {
              name: 'IC Share',
              sym: 'IC2',
              value: 0,
              revenue: 0,
              desc: 'Ordinary Share (10%) of IC',
              corporation: 'IC',
              color: '#006A14',
              text_color: 'white',
              meta: { type: :share },
            },
            {
              name: 'IC Share',
              sym: 'IC3',
              value: 0,
              revenue: 0,
              desc: 'Ordinary Share (10%) of IC',
              corporation: 'IC',
              color: '#006A14',
              text_color: 'white',
              meta: { type: :share },
            },
            {
              name: 'IC Share',
              sym: 'IC4',
              value: 0,
              revenue: 0,
              desc: 'Ordinary Share (10%) of IC',
              corporation: 'IC',
              color: '#006A14',
              text_color: 'white',
              meta: { type: :share },
            },
            {
              name: 'IC Share',
              sym: 'IC5',
              value: 0,
              revenue: 0,
              desc: 'Ordinary Share (10%) of IC',
              corporation: 'IC',
              color: '#006A14',
              text_color: 'white',
              meta: { type: :share },
            },
          ]
          return companies if intro_game?

          companies.concat([
            {
              name: 'Share Premium',
              value: 0,
              revenue: 0,
              desc: 'When the corporation issues a share during the “Issue a Share” step, it receives double the current '\
                    'share price from the bank. This company closes after use. If the corporation starts as or converts to a '\
                    'ten-share corporation, one of its treasury shares is marked as reserved. This share cannot be purchased '\
                    'while the company is open. When the ability is used, this reserve share is issued.',
              sym: 'SP',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'description', owner_type: 'corporation', count: 1, closed_when_used_up: true, when: 'issue_share' },
              ],
            },
            {
              name: 'U.S. Mail Line',
              value: 0,
              revenue: 0,
              desc: 'When running trains, the corporation earns $10 from the bank for each city it visits. '\
                    'Cities count multiple times if visited by multiple trains.',
              sym: 'USML',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'description' },
              ],
            },
            {
              name: 'Train Subsidy',
              value: 0,
              revenue: 0,
              desc: 'When buying trains from the bank, the corporation receives a 25% discount on all purchases this turn. '\
                    'This company closes after use.',
              sym: 'TS',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'train_discount',
                  discount: {
                    '2' => 0.25,
                    '3' => 0.25,
                    '4' => 0.25,
                    '0+3C' => 0.25,
                    '4+2C' => 0.25,
                    '5+1C' => 0.25,
                    '6' => 0.25,
                    'D' => 0.25,
                  },
                  owner_type: 'corporation',
                  use_across_ors: false,
                  trains: %w[2 3 4 0+3C 4+2C 5+1C 6 D],
                  count: 99,
                  closed_when_used_up: true,
                  when: 'buy_train',
                },
              ],
            },
            {
              name: 'Extra Station',
              sym: 'ES',
              value: 0,
              revenue: 0,
              desc: 'When the corporation starts, it receives one additional free token. This '\
                    'company closes after use.',
              color: nil,
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'additional_token',
                  count: 1,
                  owner_type: 'corporation',
                  when: 'track',
                  closed_when_used_up: true,
                  extra_slot: true,
                },
              ],
            },
            {
              name: 'Station Subsidy',
              value: 0,
              revenue: 0,
              desc: 'Whenever the corporation gains tokens from starting or converting, it receives them for '\
                    'free (instead of paying $40 each).',
              sym: 'SS',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'description',
                  desc_detail: 'Station Subsidy',
                  hexes: [],
                  owner_type: 'corporation',
                  count: 4,
                  closed_when_used_up: true,
                },
              ],
            },
            {
              name: 'Goodrich Transit Line',
              value: 0,
              revenue: 0,
              desc: "At any time during the corporation's operating turn, an available token may be "\
                    "placed from the corporation's charter in Chicago (H3) in the GTL slot. "\
                    'This does not count as a token action. The corporation gains a port marker for free. '\
                    'This company closes after use. It closes immediately if it remains open when Chicago '\
                    'upgrades to a brown tile.',
              sym: 'GTL',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'token',
                  when: %w[owning_corp_or_turn],
                  owner_type: 'corporation',
                  hexes: ['H3'],
                  city: 2,
                  price: 0,
                  teleport_price: 0,
                  from_owner: true,
                  count: 1,
                  extra_action: true,
                  closed_when_used_up: true,
                },
                { type: 'reservation', remove: 'sold', hex: 'H3', city: 1 },
              ],
            },
            {
              name: 'Union Stock Yards',
              value: 0,
              revenue: 0,
              desc: 'During its token placement step, the corporation may place a token in any connected '\
                    'city except Chicago (H3) or St. Louis (C18). This marker is non-blocking and does not use a city '\
                    'slot. This counts as its token placement for the turn. This company closes after use.',
              sym: 'USY',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'token',
                  when: 'token',
                  owner_type: 'corporation',
                  connected: true,
                  from_owner: true,
                  extra_slot: true,
                  special_only: true,
                  closed_when_used_up: true,
                  price: 0,
                  count: 1,
                  hexes: %w[B11 C6 C8 D15 E2 E8 E12 F3 F9 F11 G4 G6 G16 H21 I6],
                },
              ],
            },
            {
              name: 'Rush Delivery',
              value: 0,
              revenue: 0,
              desc: 'Before the “Run Trains” step, the corporation may buy one train from the bank. Emergency money '\
                    'raising may be used if it has no train. This company closes after use.',
              sym: 'RD',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'train_buy', owner_type: 'corporation', count: 1, when: 'buy_train' },
              ],
            },
            {
              name: 'Chicago-Virden Coal Co.',
              value: 0,
              revenue: 0,
              desc: 'During its tile-laying step, the corporation may lay or upgrade a town hex/tile (except Galena) '\
                    'with the #838 tile, paying any terrain costs. It must connect to one of its tokens, but '\
                    'this action does not count as the tile lay. This company closes after use.',
              sym: 'CVCC',
              meta: { type: :private, class: :B },
              abilities: [
                {
                  type: 'tile_lay',
                  tiles: %w[838],
                  hexes: MINES,
                  when: 'track',
                  owner_type: 'corporation',
                  count: 1,
                  consume_tile_lay: false,
                  reachable: true,
                  closed_when_used_up: true,
                },
              ],
            },
            {
              name: 'Planned Obsolescence',
              value: 0,
              revenue: 0,
              desc: 'When a rusting event occurs, the corporation may delay the rusting of one of its trains (except '\
                    'the “Rogers”). The train is removed from play at the end of its next “Run Trains” step. The company '\
                    'closes after use.',
              sym: 'DC',
              meta: { type: :private, class: :B },
            },
            {
              name: 'Central IL Boom',
              value: 0,
              revenue: 0,
              desc: 'In Phase D, during the tile-laying step, the corporation may upgrade Peoria (E8) '\
                    'or Springfield (E12) with '\
                    'its gray tile. This upgrade does not require a token connection, does not count as a tile lay, '\
                    'and may be done regardless of the city’s current color. The unused tile is removed from the game. '\
                    'This company closes after use.',
              sym: 'CIB',
              meta: { type: :private, class: :B },
              abilities: [
                {
                  type: 'tile_lay',
                  blocks: true,
                  tiles: %w[P4 S4],
                  hexes: %w[E8 E12],
                  when: 'track',
                  owner_type: 'corporation',
                  count: 1,
                  consume_tile_lay: false,
                  reachable: false,
                  closed_when_used_up: true,
                  special: false,
                },
              ],
            },
            {
              name: 'Frink, Walker, & Co.',
              value: 0,
              revenue: 0,
              desc: 'During its tile-laying step, the corporation may place the G1 tile in Galena (C2) for free, '\
                    'ignoring terrain costs. This does not require a token connection and does not count as the tile lay. '\
                    'While the corporation is open, it receives a $10 subsidy from the bank to its treasury whenever any '\
                    'other corporation runs one or more trains to Galena (C2).',
              sym: 'FWC',
              meta: { type: :private, class: :B },
              abilities: [
                {
                  type: 'tile_lay',
                  hexes: ['C2'],
                  tiles: ['G1'],
                  when: 'track',
                  free: true,
                  owner_type: 'corporation',
                  count: 1,
                  closed_when_used_up: false,
                },
              ],
            },
            {
              name: 'Efficient Construction',
              value: 0,
              revenue: 0,
              desc: 'When the corporation performs two tile actions in a turn, the second '\
                    'action is free instead of $20 (terrain costs still apply).',
              sym: 'EE',
              meta: { type: :private, class: :B },
              abilities: [
                { type: 'description' },
              ],
            },
            {
              name: 'Engineering Mastery',
              value: 0,
              revenue: 0,
              desc: 'During its tile-laying step, the corporation may upgrade two tiles for $20 (instead of the usual two lays '\
                    'or lay + upgrade).',
              sym: 'EM',
              meta: { type: :private, class: :B },
            },
            {
              name: 'Advanced Track',
              value: 0,
              revenue: 0,
              desc: 'During the corporation’s tile-laying step, the corporation may lay or upgrade one additional tile '\
                    'for free (terrain costs still apply). This can include a tile already acted upon that turn. This ability '\
                    'may only be used once per turn. This company closes after its second use.',
              sym: 'AT',
              meta: { type: :private, class: :B },
              abilities: [
                {
                  type: 'tile_lay',
                  when: 'track',
                  owner_type: 'corporation',
                  tiles: [],
                  hexes: [],
                  count: 2,
                  count_per_or: 1,
                  consume_tile_lay: false,
                  reachable: true,
                  closed_when_used_up: true,
                  special: false,
                },
              ],
            },
            {
              name: 'Illinois Steel Bridge Co.',
              value: 0,
              revenue: 0,
              desc: 'The corporation ignores terrain costs for rivers and lakes. Each time it lays a yellow tile on a '\
                    'lake or across a river, it earns $10 from the bank.',
              sym: 'ISBC',
              meta: { type: :private, class: :B },
              abilities: [
                { type: 'tile_discount', terrain: :water, owner_type: 'corporation', discount: 20 },
                { type: 'tile_income', terrain: :water, income: 10, owner_type: 'corporation', owner_only: true },
              ],
            },
          ])
          companies
        end
      end
    end
  end
end
