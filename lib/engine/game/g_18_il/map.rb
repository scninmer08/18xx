# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Map
        LAYOUT = :flat
        LOCATION_NAMES = {
          'A10' => 'Omaha +80 E/W',
          'B3' => 'Sioux City +80 E/W',
          'B11' => 'Quincy',
          'B17' => 'St. Louis',
          'C2' => 'Galena',
          'C6' => 'Rock Island',
          'D5' => 'Sterling',
          'D9' => 'Canton',
          'D13' => 'Jacksonville',
          'D15' => 'Alton',
          'D17' => 'Belleville',
          'E2' => 'Freeport',
          'E6' => 'La Salle',
          'E8' => 'Peoria',
          'E12' => 'Springfield',
          'E16' => 'Breese',
          'E22' => 'Cairo',
          'F3' => 'Rockford',
          'F5' => 'Ottawa',
          'F9' => 'Bloomington',
          'F11' => 'Decatur',
          'F13' => 'Pana',
          'F17' => 'Centralia',
          'F21' => 'Marion',
          'F25' => 'New Orleans',
          'G2' => 'Milwaukee +100 N/S',
          'G4' => 'Aurora',
          'G6' => 'Joliet',
          'G10' => 'Champaign',
          'G16' => 'Effingham',
          'G22' => 'Harrisburg',
          'H3' => 'Chicago',
          'H7' => 'Kankakee',
          'H11' => 'Danville',
          'H21' => 'Evansville',
          'I2' => 'Lake Michigan',
          'I6' => 'Detroit',
          'I12' => 'Indianapolis',
          'I18' => 'Louisville',
        }.freeze

        PORT_HEXES = %w[H1].freeze
        PORT_PERMIT_HEX = 'I4'
        TOWN_HEXES = %w[C2 D9 D13 D17 E6 E14 E16 F5 F13 F21 G22 H11].freeze
        CITY_HEXES = %w[B11 C6 C18 D5 D15 E2 E8 E12 E22 F3 F9 F11 F17 G4 G6 G10 G16 H3 H7 H21 I6].freeze
        STL_HEXES = %w[B17 C16 C18].freeze
        STL_TOKEN_HEX = ['C18'].freeze
        CHICAGO_HEX = ['H3'].freeze
        SPRINGFIELD_HEX = ['E12'].freeze
        IC_LINE_CITY_HEXES = %w[H7 G10 F17 E22].freeze
        BOOM_HEXES = %w[E8 E12].freeze
        BOOM_TILES = %w[P4 S4].freeze
        GALENA_HEX = %w[C2].freeze
        JACKSONVILLE_HEX = %w[D13].freeze
        CVCC_TOWN_HEXES = (TOWN_HEXES - GALENA_HEX - JACKSONVILLE_HEX).freeze
        USY_CITY_HEXES = (CITY_HEXES - CHICAGO_HEX - STL_TOKEN_HEX - IC_LINE_CITY_HEXES).freeze
        PORT_ICON = 'port'.freeze

        BOOM_HEX_TILE = { 'E8' => 'P4', 'E12' => 'S4' }.freeze

        ASSIGNMENT_TOKENS = {
          'port' => '/icons/18_il/port.svg',
        }.freeze

        IC_LINE_ORIENTATION = {
          'H7' => [1, 3],
          'G8' => [4, 0],
          'G10' => [3, 0],
          'G12' => [3, 0],
          'G14' => [1, 3],
          'F15' => [4, 0],
          'F17' => [3, 0],
          'F19' => [1, 3],
          'E20' => [4, 0],
          'E22' => [3, 0],
        }.freeze

        BLOCKING_LOGOS = [
          '/logos/18_il/yellow_blocking.svg', '/logos/18_il/green_blocking.svg',
          '/logos/18_il/brown_blocking.svg', '/logos/18_il/gray_blocking.svg'
        ].freeze

        def game_hexes
          {
            blue: {
              ['H1'] => 'town=revenue:20,symbol:40,groups:port;path=a:1,b:_0;path=a:5,b:_0;border=edge:5;'\
                        'icon=image:18_il/port,sticky:1',
              ['I2'] => 'offboard=revenue:0;path=a:1,b:2;border=edge:0;border=edge:2;',
              ['I4'] => 'city=revenue:0,loc:1.5;city=revenue:0,loc:3;city=revenue:0,loc:4.5;city=revenue:0,loc:0;'\
                        'border=edge:3;',
            },

            white: {
              %w[B13 C10 C8 C12 D3 D7 E4 E14 E18 F7 G18 H9 H13] => '',
              %w[E2 F3 F9 F11 G4 G16] => 'city=revenue:0',
              %w[D9 F13 E16 H11] => 'town=revenue:0',
              ['B11'] => 'city=revenue:0;border=edge:2,type:water,cost:20',
              ['C2'] => 'label=G;town=revenue:0,groups:Galena;upgrade=cost:60,terrain:mountain;'\
                        'border=edge:1,type:water,cost:20',
              ['C6'] => 'city=revenue:0;border=edge:2,type:water,cost:20',
              ['C14'] => 'border=edge:0,type:water,cost:20',
              ['D5'] => 'city=revenue:0',
              ['D11'] => 'upgrade=cost:20,terrain:water',
              ['D15'] => 'city=revenue:0;border=edge:1,type:water,cost:20',
              ['D17'] => 'town=revenue:0;border=edge:2,type:water,cost:20',
              ['D19'] => 'border=edge:0',
              ['E6'] => 'town=revenue:0;upgrade=cost:20,terrain:water',
              ['E10'] => 'upgrade=cost:20,terrain:water',
              ['E12'] => 'label=S;city=revenue:20;path=a:1,b:_0',
              ['E20'] => 'path=a:4,b:0,track:future;icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['E22'] => 'label=C;city=revenue:0;path=a:3,b:_0,track:future;path=a:0,b:_0,track:future;'\
                         'border=edge:0,type:water,cost:20;icon=image:18_il/ic_cube,sticky:1',
              ['F5'] => 'town=revenue:0;upgrade=cost:20,terrain:water',
              ['F15'] => 'path=a:4,b:0,track:future;icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['F17'] => 'label=C;city=revenue:0;path=a:3,b:_0,track:future;path=a:0,b:_0,track:future;'\
                         'icon=image:18_il/ic_cube,sticky:1,loc:1.5;upgrade=cost:20,terrain:water',
              ['F19'] => 'path=a:1,b:3,track:future;upgrade=cost:20,terrain:water;icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['F21'] => 'town=revenue:0;border=edge:0,type:water,cost:20',
              ['G6'] => 'city=revenue:0;upgrade=cost:20,terrain:water',
              ['G8'] => 'path=a:4,b:0,track:future;icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['G12'] => 'path=a:3,b:0,track:future;icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['G14'] => 'path=a:1,b:3,track:future;upgrade=cost:20,terrain:water;icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['G10'] => 'label=C;city=revenue:0;path=a:3,b:_0,track:future;path=a:0,b:_0,track:future;'\
                         'icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['G20'] => 'border=edge:5,type:water,cost:20',
              ['G22'] => 'town=revenue:0;'\
                         'border=edge:0,type:water,cost:20;border=edge:1,type:water,cost:20;border=edge:4,type:water,cost:20',
              ['H7'] => 'label=K;city=revenue:0;path=a:1,b:_0,track:future;path=a:3,b:_0,track:future;'\
                        'icon=image:18_il/ic_cube,sticky:1,loc:1.5',
              ['H17'] => 'border=edge:5,type:water,cost:20',
              ['H19'] => 'border=edge:4,type:water,cost:20',
            },

            yellow: {
              ['B9'] => 'border=edge:1,type:water,cost:20;path=a:0,b:4',
              ['D13'] => 'label=J;town=revenue:10;path=a:4,b:_0',
              ['H3'] => 'label=Chi;city=revenue:10,loc:1;city=revenue:10,loc:4;city=revenue:10,loc:5.5;'\
                        'path=a:4,b:_1;path=a:0,b:_2',
              ['H5'] => 'path=a:3,b:0',
              ['E8'] => 'label=P;city=revenue:20;path=a:3,b:_0;upgrade=cost:20,terrain:water',
            },

            gray: {
              ['B7'] => 'offboard=revenue:0;path=a:4,b:_0',
              ['D1'] => 'path=a:1,b:5',
              ['F1'] => 'path=a:1,b:0',
              ['H15'] => 'path=a:1,b:3',
              ['H21'] => 'city=revenue:30;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;border=edge:1,type:water,cost:20;'\
                         'border=edge:2,type:water,cost:20',
            },

            red: {
              ['A10'] => 'label=W;offboard=revenue:yellow_30|brown_50,groups:West;path=a:4,b:_0;path=a:5,b:_0;'\
                         'border=edge:4,type:water,cost:20;border=edge:5,type:water,cost:20',
              ['B3'] => 'label=W;offboard=revenue:yellow_20|brown_40,groups:West;path=a:4,b:_0;path=a:0,b:_0;'\
                        'border=edge:0;border=edge:4,type:water,cost:20;border=edge:5',
              ['B5'] => 'path=a:3,b:5;border=edge:3;border=edge:4;border=edge:5,type:water,cost:20',
              ['B17'] => 'offboard=revenue:yellow_60|brown_100,groups:STL;path=a:4,b:_0;border=edge:3;'\
                         'border=edge:4;border=edge:5',
              ['C4'] => 'border=edge:1;border=edge:2',
              ['C16'] => 'offboard=revenue:0,groups:STL;path=a:3,b:1;path=a:4,b:1;path=a:5,b:1;border=edge:0;'\
                         'border=edge:1;border=edge:2;border=edge:3,'\
                         'type:water,cost:20;border=edge:4,type:water,cost:20;border=edge:5,type:water,cost:20',
              ['C18'] => 'offboard=revenue:0,groups:STL;city=revenue:0,loc:1.5;city=revenue:0,loc:3;'\
                         'city=revenue:0,loc:4.5;city=revenue:0,loc:0;border=edge:2;border=edge:3',
              ['E24'] => 'path=a:3,b:5;border=edge:5;border=edge:4;border=edge:3,type:water,cost:20',
              ['F23'] => 'path=a:3,b:0;path=a:4,b:0;border=edge:0;border=edge:1;border=edge:3,type:water,cost:20;'\
                         'border=edge:4,type:water,cost:20;border=edge:5',
              ['F25'] => 'label=S;offboard=revenue:yellow_40|brown_60,groups:South;path=a:2,b:_0;path=a:3,b:_0;'\
                         'path=a:4,b:_0;border=edge:2;border=edge:3;border=edge:4',
              ['G2'] => 'label=N;offboard=revenue:yellow_20|brown_40,groups:North;path=a:1,b:_0;path=a:4,b:_0;path=a:5,b:_0',
              ['G24'] => 'path=a:3,b:1;border=edge:1;border=edge:2;border=edge:3,type:water,cost:20',
              ['I6'] => 'label=E;city=revenue:yellow_30|brown_40,groups:East;path=a:1,b:_0,terminal:1;border=edge:0;'\
                        'path=a:2,b:_0,terminal:1;border=edge:0;path=a:0,b:_0,terminal:1,lanes:2',
              ['I8'] => 'path=a:3,b:1,a_lane:2.0;path=a:3,b:2,a_lane:2.1;border=edge:3',
              ['I12'] => 'label=E;offboard=revenue:yellow_30|brown_40,groups:East;path=a:1,b:_0;path=a:2,b:_0',
              ['I18'] => 'label=E;offboard=revenue:yellow_30|brown_50,groups:East;path=a:1,b:_0;path=a:2,b:_0;'\
                         'border=edge:1,type:water,cost:20;border=edge:2,type:water,cost:20',
            },
          }
        end
      end
    end
  end
end
