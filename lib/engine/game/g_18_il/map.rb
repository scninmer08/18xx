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
          'E6' => 'Bureau Junction',
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
          'H7' => 'Kankakee',
          'H11' => 'Danville',
          'H21' => 'Evansville',
          'I2' => 'Lake Michigan',
          'I6' => 'Detroit',
          'I12' => 'Indianapolis',
          'I18' => 'Louisville',
        }.freeze

        def game_hexes
          {
            blue: {
              ['H1'] => 'town=revenue:20,symbol:40,groups:port;path=a:1,b:_0;path=a:5,b:_0;border=edge:5;'\
                        'icon=image:18_il/port,sticky:1',
              ['I2'] => 'offboard=revenue:0;path=a:1,b:2;border=edge:0;border=edge:2',
              ['I4'] => 'offboard=revenue:0;border=edge:3',
            },

            white: {
              %w[B13 C10 C8 C12 D3 D7 D11 E4 E10 E14 E18 F7 G18 H9 H13] => '',
              %w[E2 F3 F9 F11 G4 G16] => 'city=revenue:0',
              %w[D9 F13 E16 H11] => 'town=revenue:0',
              ['B9'] => 'border=edge:1,type:water,cost:20',
              ['B11'] => 'city=revenue:0;border=edge:2,type:water,cost:20',
              ['C2'] => 'label=G;town=revenue:0,groups:Galena;upgrade=cost:60,terrain:mountain;'\
                        'border=edge:1,type:water,cost:20',
              ['C6'] => 'city=revenue:0;border=edge:2,type:water,cost:20',
              ['C14'] => 'border=edge:1,type:water,cost:20;border=edge:0,type:water,cost:20',
              ['D5'] => 'city=revenue:0',
              ['D15'] => 'city=revenue:0;border=edge:1,type:water,cost:20',
              ['D17'] => 'town=revenue:0;border=edge:2,type:water,cost:20',
              ['D19'] => 'border=edge:0',
              ['E6'] => 'town=revenue:0;upgrade=cost:20,terrain:water',
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
              ['D13'] => 'label=J;town=revenue:10;path=a:4,b:_0',
              ['H3'] => 'label=Chi;city=revenue:10,loc:1.5;city=revenue:10,loc:3.5;city=revenue:10,loc:5.5;'\
                        'path=a:4,b:_1;path=a:0,b:_2',
              ['H5'] => 'path=a:3,b:0',
              ['E8'] => 'label=P;city=revenue:20;path=a:3,b:_0;upgrade=cost:20,terrain:water',
            },

            gray: {
              ['B7'] => 'offboard=revenue:0;path=a:4,b:_0',
              ['D1'] => 'path=a:1,b:5',
              ['F1'] => 'path=a:1,b:0',
              ['H15'] => 'path=a:1,b:3',
              ['H21'] => 'city=revenue:40;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;border=edge:1,type:water,cost:20;'\
                         'border=edge:2,type:water,cost:20',
            },

            red: {
              ['A10'] => 'label=W;offboard=revenue:yellow_30|brown_50,groups:West;path=a:4,b:_0;path=a:5,b:_0;'\
                         'border=edge:4,type:water,cost:20;border=edge:5,type:water,cost:20',
              ['B3'] => 'label=W;offboard=revenue:yellow_20|brown_40,groups:West;path=a:4,b:_0;path=a:0,b:_0;'\
                        'border=edge:0;border=edge:4,type:water,cost:20;border=edge:5',
              ['B5'] => 'path=a:3,b:5;border=edge:3;border=edge:4;border=edge:5,type:water,cost:20',
              ['B15'] => 'offboard=revenue:0,groups:STL;path=a:4,b:5;border=edge:0;'\
                         'border=edge:4,type:water,cost:20;border=edge:5',
              ['B17'] => 'offboard=revenue:yellow_60|brown_100,groups:STL;path=a:4,b:_0;border=edge:3;'\
                         'border=edge:4;border=edge:5',
              ['C4'] => 'border=edge:1;border=edge:2',
              ['C16'] => 'offboard=revenue:0,groups:STL;path=a:2,b:1;path=a:3,b:1;path=a:4,b:1;path=a:5,b:1;border=edge:0;'\
                         'border=edge:1;border=edge:2;border=edge:3,'\
                         'type:water,cost:20;border=edge:4,type:water,cost:20;border=edge:5,type:water,cost:20',
              ['C18'] => 'offboard=revenue:0,groups:STL;city=revenue:0,slots:4;border=edge:2;border=edge:3',
              ['E24'] => 'path=a:3,b:5;border=edge:5;border=edge:4;border=edge:3,type:water,cost:20',
              ['F23'] => 'path=a:3,b:0;path=a:4,b:0;border=edge:0;border=edge:1;border=edge:3,type:water,cost:20;'\
                         'border=edge:4,type:water,cost:20;border=edge:5',
              ['F25'] => 'label=S;offboard=revenue:yellow_50|brown_60,groups:South;path=a:2,b:_0;path=a:3,b:_0;'\
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
