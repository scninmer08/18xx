# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'

module Engine
  module Game
    module G18IL
      module Companies
        def game_companies
          companies = [
            {
              name: 'Illinois River Railroad',
              sym: 'IR',
              value: 0,
              revenue: 0,
              corporation: 'IR',
              color: '#2165ae',
              text_color: 'white',
              meta: { type: :concession, share_count: 2 },
            },
            {
              name: 'Northern Cross Railroad',
              sym: 'NC',
              value: 0,
              revenue: 0,
              corporation: 'NC',
              color: '#694a98',
              text_color: 'white',
              meta: { type: :concession, share_count: 2 },
            },
            {
              name: 'Galena and Chicago Union Railroad',
              sym: 'G&CU',
              value: 0,
              revenue: 0,
              corporation: 'G&CU',
              color: '#e0c6ae',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Rock Island Line',
              sym: 'RI',
              value: 0,
              revenue: 0,
              corporation: 'RI',
              color: '#e84b1c',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Chicago, Burlington & Quincy Railroad',
              sym: 'CBQ',
              value: 0,
              revenue: 0,
              corporation: 'CBQ',
              color: '#8dc8e7',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Vandalia Railroad',
              sym: 'V',
              value: 0,
              revenue: 0,
              corporation: 'V',
              color: '#fdc600',
              text_color: 'black',
              meta: { type: :concession, share_count: 5 },
            },
            {
              name: 'Wabash Railroad',
              sym: 'WAB',
              value: 0,
              revenue: 0,
              corporation: 'WAB',
              color: '#7e8892',
              text_color: 'black',
              meta: { type: :concession, share_count: 10 },
            },
            {
              name: 'Chicago and Eastern Illinois Railroad',
              sym: 'C&EI',
              value: 0,
              revenue: 0,
              corporation: 'C&EI',
              color: '#7d3b2c',
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
              color: '#0d8743',
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
              color: '#0d8743',
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
              color: '#0d8743',
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
              color: '#0d8743',
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
              color: '#0d8743',
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
              color: '#0d8743',
              text_color: 'white',
              meta: { type: :share },
            },
          ]
          return companies if intro_game?

          companies.concat([
            {
              name: 'Goodrich Transit Line',
              value: 0,
              revenue: 0,
              desc: "(10 SHARE) At any time during the corporation's operating turn, it may flip this company to gain a port " \
                    "permit for free, then optionally place an available token from the corporation's charter in Chicago (H3). " \
                    'This does not count as a token action. Chicago has a reserved sta-tion slot for GTL when the tile is '\
                    'yellow or green; this reservation is not present when Chicago is upgraded to a brown or gray tile.',
              sym: 'GTL',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'token',
                  when: %w[owning_corp_or_turn],
                  owner_type: 'corporation',
                  hexes: self.class::CHICAGO_HEX,
                  city: 2,
                  price: 0,
                  teleport_price: 0,
                  from_owner: true,
                  count: 1,
                  extra_action: true,
                },
                { type: 'reservation', remove: 'sold', hex: self.class::CHICAGO_HEX.first, city: 1 },
              ],
            },
            {
              name: 'Interstate Commerce Corridor',
              sym: 'ICC',
              value: 0,
              revenue: 0,
              desc: '(10 SHARE) When running trains, the corporation’s revenue is increased by an additional $60 if at least '\
                    'one of its trains qualifies for a N/S or E/W bonus.',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'description', owner_type: 'corporation' },
              ],
            },
            {
              name: 'Route Extension',
              value: 0,
              revenue: 0,
              desc: '(10 SHARE) When the owning corporation runs trains, it may add one additional city or offboard stop to one '\
                    'of its trains.',
              sym: 'RE',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'description',
                  desc_detail: 'Route Extension',
                  hexes: [],
                  owner_type: 'corporation',
                },
              ],
            },
            {
              name: 'Rush Delivery',
              value: 0,
              revenue: 0,
              desc: "(10 SHARE) Before the corporation's “Run Trains” step, it may flip this company to buy one train " \
                    'from the bank. Emergency money raising may be used if it has no train.',
              sym: 'RD',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'train_buy', owner_type: 'corporation', count: 1, when: 'buy_train' },
              ],
            },
            {
              name: 'Share Premium',
              value: 0,
              revenue: 0,
              desc: "(10 SHARE) During the corporation's “Issue a Share” step, it may flip this company to issue a share for "\
                    'double its current share price.',
              sym: 'SP',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'description', owner_type: 'corporation', count: 1, when: 'issue_share' },
              ],
            },
            {
              name: 'Train Subsidy',
              value: 0,
              revenue: 0,
              desc: '(10 SHARE) When the corporation buys a train from the bank, it may flip this company to receive a 25% '\
                    'discount on that train.',
              sym: 'TS',
              meta: { type: :private, class: :A },
              abilities: [
                {
                  type: 'train_discount',
                  discount: 0.25,
                  owner_type: 'corporation',
                  count: 1,
                  remove_when_used_up: false,
                  trains: self.class::TRAINS.reject { |t| t[:reserved] }
                             .flat_map { |t| [t[:name]] + (t[:variants]&.map { |v| v[:name] } || []) },
                  when: 'buy_train',
                },
              ],
            },
            {
              name: 'U.S. Mail Line',
              value: 0,
              revenue: 0,
              desc: '(10 SHARE) The owning corporation receives a $10 subsidy per city visited by its trains. '\
                    'Each city is counted only once, regardless of how many trains visit it.',
              sym: 'USML',
              meta: { type: :private, class: :A },
              abilities: [
                { type: 'description' },
              ],
            },
            {
              name: 'Union Stock Yards',
              value: 0,
              revenue: 0,
              desc: "(10 SHARE) During the corporation's token placement step, it may flip this company to place "\
                    'a token in any city to which it is connected by route, except the IC-Line cities (H3, H7, G10, F17, E22). '\
                    'This token is non-blocking and does not use a city slot. This counts as its token placement for the turn.',
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
                  price: 0,
                  count: 1,
                  hexes: self.class::USY_CITY_HEXES,
                },
              ],
            },
            {
              name: 'Advanced Track',
              value: 0,
              revenue: 0,
              desc: '(5 SHARE) During the corporation’s tile-laying step, it may lay or upgrade one additional tile '\
                    'for free (terrain costs still apply). This can include a tile already acted upon that turn. This ability '\
                    'may only be used once per turn. This company flips after its second use.',
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
                  special: false,
                },
              ],
            },
            {
              name: 'Central IL Boom',
              value: 0,
              revenue: 0,
              desc: "(5 SHARE) In Phase 8 or later, during the corporation's tile-laying step, it may flip this company to "\
                    'upgrade Peoria (E8) or Springfield (E12) with the corresponding gray tile. This upgrade does not need to '\
                    'be connected by route, does not count as a tile lay, and may be done regardless of the city’s current '\
                    'color. The unused tile is removed from the game.',
              sym: 'CIB',
              meta: { type: :private, class: :B },
              abilities: [
                {
                  type: 'tile_lay',
                  blocks: true,
                  tiles: self.class::BOOM_TILES,
                  hexes: self.class::BOOM_HEXES,
                  when: 'track',
                  owner_type: 'corporation',
                  count: 1,
                  consume_tile_lay: false,
                  reachable: false,
                  special: false,
                },
              ],
            },
            {
              name: 'Chicago-Virden Coal Co.',
              value: 0,
              revenue: 0,
              desc: "(5 SHARE) During the corporation's tile-laying step, it may flip this company to lay or upgrade a town "\
                    'hex/tile (except Galena or Jacksonville) with the #838 tile, paying any terrain costs. It must be '\
                    'connected by route but this action does not count as the tile lay.',
              sym: 'CVCC',
              meta: { type: :private, class: :B },
              abilities: [
                {
                  type: 'tile_lay',
                  tiles: %w[838],
                  hexes: self.class::CVCC_TOWN_HEXES,
                  when: 'track',
                  owner_type: 'corporation',
                  count: 1,
                  consume_tile_lay: false,
                  reachable: true,
                },
              ],
            },
            {
              name: 'Efficient Construction',
              value: 0,
              revenue: 0,
              desc: '(5 SHARE) Whenever the corporation performs two tile actions in a turn, the second '\
                    'action is free instead of $20 (terrain costs still apply).',
              sym: 'EC',
              meta: { type: :private, class: :B },
              abilities: [
                { type: 'description' },
              ],
            },
            {
              name: 'Engineering Mastery',
              value: 0,
              revenue: 0,
              desc: "(5 SHARE) During the corporation's tile-laying step, it may upgrade two tiles for $20 (instead of the "\
                    'usual two lays or lay + upgrade).',
              sym: 'EM',
              meta: { type: :private, class: :B },
            },
            {
              name: 'Frink, Walker & Co.',
              value: 0,
              revenue: 0,
              desc: "(5 SHARE) During the corporation's tile-laying step, the corporation may place the G1 tile in Galena (C2) "\
                    'for free, ignoring terrain costs. This does not need to be connected by route and does not count as the '\
                    'tile lay. While the corporation is open, it receives a $10 subsidy whenever any other corporation runs at '\
                    'least one train to Galena (C2).',
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
                  reachable: false,
                  count: 1,
                },
              ],
            },
            {
              name: 'Illinois Steel Bridge Co.',
              value: 0,
              revenue: 0,
              desc: '(5 SHARE) The corporation ignores terrain costs for rivers and lakes. Each time it lays a yellow tile on a '\
                    'lake or across a river, it receives a $10 subsidy.',
              sym: 'ISBC',
              meta: { type: :private, class: :B },
              abilities: [
                { type: 'tile_discount', terrain: :water, owner_type: 'corporation', discount: 20 },
                { type: 'tile_income', terrain: :water, income: 10, owner_type: 'corporation', owner_only: true },
              ],
            },
            {
              name: 'Planned Obsolescence',
              value: 0,
              revenue: 0,
              desc: '(5 SHARE) When a rusting event occurs, the corporation may flip this company to delay the rusting '\
                    'of one of its trains. The train is removed from play at the end of its next “Run Trains” step.',
              sym: 'PO',
              meta: { type: :private, class: :B },
            },
          ])
          companies
        end
      end
    end
  end
end
