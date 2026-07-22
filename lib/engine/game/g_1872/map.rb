# frozen_string_literal: true

module Engine
  module Game
    module G1872
      module Map
        LAYOUT = :pointy

        TILES = {
          '8' => 1,
          '9' => 36,
          '53' => 4,
          '57' => 12,
          '61' => 4,
          '68' => 2,
          '141' => 6,
          '141a' => {
            'count' => 4,
            'color' => 'brown',
            'code' => 'town=revenue:10;path=a:0,b:_0;path=a:3,b:_0;path=a:1,b:_0;path=a:1,b:3',
          },

          '141b' => {
            'count' => 4,
            'color' => 'brown',
            'code' => 'town=revenue:10;path=a:0,b:_0;path=a:3,b:_0;path=a:1,b:_0;path=a:0,b:1',
          },
          '142' => 6,
          '142a' => {
            'count' => 4,
            'color' => 'brown',
            'code' => 'town=revenue:10;path=a:0,b:_0;path=a:5,b:_0;path=a:3,b:_0;path=a:3,b:5',
          },
          '142b' => {
            'count' => 4,
            'color' => 'brown',
            'code' => 'town=revenue:10;path=a:0,b:_0;path=a:5,b:_0;path=a:3,b:_0;path=a:0,b:5',
          },
          '168d' => {
            'count' => 2,
            'color' => 'green',
            'code' => 'city=revenue:40;city=revenue:40;path=a:0,b:_0;path=a:_0,b:3;'\
                      'path=a:1,b:_1;path=a:_1,b:4;label=OO',
          },
          '205' => 6,
          '206' => 6,
          '235' => 2,
          '441' => 6,
          '442' => 6,
          '611' => 6,
          'X00' =>
          {
            'count' => 4,
            'color' => 'yellow',
            'code' =>
            'city=revenue:30;path=a:1,b:_0;path=a:3,b:_0;path=a:5,b:_0;label=B',
          },
          'DEN1' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:40;city=revenue:40;city=revenue:40;city=revenue:40;'\
                      'path=a:0,b:_0;path=a:_0,b:2;path=a:3,b:_1;path=a:_1,b:2;path=a:4,b:_2;'\
                      'path=a:_2,b:2;path=a:5,b:_3;path=a:_3,b:2;label=Den',
          },
          'DEN2' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'city=revenue:70;city=revenue:70;city=revenue:70;city=revenue:70;'\
                      'path=a:0,b:_0;path=a:_0,b:2;path=a:3,b:_1;path=a:_1,b:2;path=a:4,b:_2;'\
                      'path=a:_2,b:2;path=a:5,b:_3;path=a:_3,b:2;label=Den',
          },
          'DEN3' => {
            'count' => 1,
            'color' => 'gray',
            'code' => 'city=revenue:90;city=revenue:90;city=revenue:90;city=revenue:90;'\
                      'path=a:0,b:_0;path=a:_0,b:2;path=a:3,b:_1;path=a:_1,b:2;path=a:4,b:_2;'\
                      'path=a:_2,b:2;path=a:5,b:_3;path=a:_3,b:2;label=Den',
          },
        }.freeze

        LOCATION_NAMES = {
          'A3' => 'Pacific Northwest',
          'B42' => 'Chicago +100 E/W',
          'B4' => 'Cheyenne',
          'B20' => 'North Platte',
          'B28' => 'Grand Island',
          'B38' => 'Omaha',
          'C11' => 'Sterling',
          'C3' => 'San Francisco',
          'C35' => 'Lincoln',
          'D4' => 'Greeley',
          'D16' => 'Imperial',
          'D24' => 'Holdrege',
          'D30' => 'Hastings',
          'E13' => 'Yuma',
          'E3' => 'Colorado Mines',
          'E21' => 'McCook',
          'E33' => 'Fairbury',
          'F4' => 'Denver',
          'F24' => 'Norton',
          'F32' => 'Belleville',
          'F36' => 'Marysville',
          'F40' => 'Atchison',
          'G13' => 'Burlington',
          'G17' => 'Goodland',
          'H4' => 'Colorado Springs',
          'H26' => 'Hays',
          'H32' => 'Salina',
          'H34' => 'Junction City',
          'H38' => 'Topeka',
          'H42' => 'Kansas City',
          'H44' => 'St. Louis +100 E/W',
          'I13' => 'Kit Carson',
          'I19' => 'Scott City',
          'J6' => 'Pueblo',
          'J28' => 'Great Bend',
          'I3' => 'Santa Fe',
          'J30' => 'Hutchinson',
          'J36' => 'Emporia',
          'K9' => 'La Junta',
          'K19' => 'Garden City',
          'K23' => 'Dodge City',
          'K33' => 'Wichita',
        }.freeze

        TERRITORY_BORDERS = {
          # Colorado / Nebraska
          'B4' => [5],
          'B6' => [0, 4, 5],
          'B8' => [0, 5],
          'B10' => [0, 5],
          'B12' => [0, 5],
          'B14' => [0],

          # Colorado / Kansas-Nebraska
          'C13' => [4],
          'D14' => [3, 4, 5],
          'E13' => [4],
          'F14' => [4, 5],
          'G13' => [4],
          'H14' => [3, 4, 5],
          'I13' => [4],
          'J14' => [3, 4, 5],
          'K13' => [4],

          # Kansas / Nebraska
          'E15' => [0, 5],
          'E17' => [0, 5],
          'E19' => [0, 5],
          'E21' => [0, 5],
          'E23' => [0, 5],
          'E25' => [0, 5],
          'E27' => [0, 5],
          'E29' => [0, 5],
          'E31' => [0, 5],
          'E33' => [0, 5],
          'E35' => [0, 5],
          'E37' => [0, 5],
          'E39' => [0, 5],
          'E41' => [0, 5],
        }.freeze

        LAND_GRANT_TERRITORIES = {
          colorado: %w[C11 D4 E13 G13 H4 I13 J6 K9],
          kansas: %w[F24 F32 G17 H32 H34 I19 J28 J30 K19 K23],
          nebraska: %w[B20 B28 D16 D24 D30 E21 E33],
          wyoming: %w[B4],
        }.freeze

        HEXES = {
          white: {
            %w[B6 B8 B10 B24 B32 B34 B36 C5 C7 C9 C31 C33 C41 D14 D18 D20 D28 D32 D34 D36
               E15 E17 E19 E23 E25 E27 E29 E31 E35 E37 F6 F8 F10 F12 F14 F16 F18 F20 F22 F26 F28 F30 F34
               F38 G5 G7 G9 G11 G15 G19 G21 G23 G25 G27 G29 G31 G33 H6 H8 H10 H12 H14 H16 H18 H20 H22
               H24 H28 H30 I9 I11 I15 I17 I21 I23 I25 I37 J16 J18 J20 J22 J24 J34 J38 K5 K29 K35
               K37] => '',
            %w[B22 I7 I31 J14] => 'border=edge:0,type:water,cost:20',
            ['C23'] => 'border=edge:0,type:water,cost:20;border=edge:1,type:water,cost:20;'\
                       'border=edge:5,type:water,cost:20',
            %w[B16 B18 D6 D8 G37 I5 I29 J12] =>
              'border=edge:0,type:water,cost:20;border=edge:5,type:water,cost:20',
            %w[K17 K21] =>
              'border=edge:0,type:water;border=edge:5,type:water,cost:20',
            %w[B30 B40 F42] => 'border=edge:1,type:water,cost:20',
            %w[D40 E41 J32] => 'border=edge:1,type:water,cost:20;border=edge:0,type:water,cost:20',
            ['J8'] => 'border=edge:1,type:water,cost:20;border=edge:0,type:water,cost:20;'\
                      'border=edge:5,type:water,cost:20',
            ['K27'] => 'border=edge:1,type:water,cost:20;border=edge:2,type:water,cost:20',
            ['H36'] => 'border=edge:1,type:water,cost:20;border=edge:2,type:water,cost:20;'\
                       'border=edge:3,type:water,cost:20',
            ['K15'] => 'border=edge:1,type:water,cost:20;border=edge:5,type:water,cost:20;'\
                       'border=edge:0,type:water',
            %w[C29 D26 E11 I35] => 'border=edge:2,type:water,cost:20',
            ['D12'] => 'border=edge:2,type:water,cost:20;border=edge:1,type:water,cost:20',
            ['C39'] => 'border=edge:2,type:water,cost:20;border=edge:1,type:water,cost:20;'\
                       'border=edge:0,type:water,cost:20',
            ['K11'] => 'border=edge:2,type:water,cost:20;border=edge:3,type:water,cost:20',
            %w[D22 I33 I39 J4 K7] => 'border=edge:3,type:water,cost:20',
            ['H40'] => 'border=edge:3,type:water,cost:20;border=edge:0,type:water,cost:20;'\
                       'border=edge:5,type:water,cost:20;border=edge:4,type:water,cost:20;'\
                       'border=edge:1,type:water,cost:20',
            %w[C15 C17 C19 E5 E7 E9 I41] =>
              'border=edge:3,type:water,cost:20;border=edge:2,type:water,cost:20',
            ['C13'] => 'border=edge:3,type:water,cost:20;border=edge:2,type:water,cost:20;'\
                       'border=edge:1,type:water,cost:20',
            %w[E39 K31] => 'border=edge:3,type:water,cost:20;border=edge:4,type:water,cost:20',
            ['C37'] => 'border=edge:4,type:water,cost:20',
            ['G39'] => 'border=edge:4,type:water,cost:20;border=edge:0,type:water,cost:20',
            ['K25'] => 'border=edge:4,type:water,cost:20;border=edge:0,type:water;'\
                       'border=edge:5,type:water,cost:20',
            ['K13'] => 'border=edge:4,type:water,cost:20;border=edge:2,type:water,cost:20;'\
                       'border=edge:3,type:water,cost:20',
            ['D38'] => 'border=edge:4,type:water,cost:20;border=edge:3,type:water,cost:20',
            ['C21'] => 'border=edge:4,type:water,cost:20;border=edge:3,type:water,cost:20;'\
                       'border=edge:2,type:water,cost:20',
            %w[B12 B26 G35 I27] => 'border=edge:5,type:water,cost:20',
            %w[B14 J10] => 'border=edge:5,type:water,cost:20;border=edge:0,type:water,cost:20',
            ['J26'] => 'border=edge:5,type:water,cost:20;border=edge:4,type:water,cost:20',
            %w[C25 D10] => 'border=edge:5,type:water,cost:20;border=edge:4,type:water,cost:20;'\
                           'border=edge:0,type:water,cost:20',
            %w[C35 D16 D30 E13 E21 E33 G13 G17 H26 H32 I19 J36 F24 F32 I13] => 'city=revenue:0',
            ['B4'] => 'city=revenue:0;label=B',
            ['H4'] => 'city=revenue:0;label=B',
            %w[B20 K19 K23] => 'city=revenue:0;border=edge:0,type:water,cost:20;'\
                               'border=edge:5,type:water,cost:20',
            ['C27'] => 'border=edge:1,type:water,cost:20;border=edge:2,type:water,cost:20;'\
                       'border=edge:3,type:water,cost:20',
            ['G41'] => 'border=edge:2,type:water,cost:20;border=edge:1,type:water,cost:20;'\
                       'border=edge:0,type:water,cost:20',
            ['J28'] => 'city=revenue:0;border=edge:2,type:water,cost:20;border=edge:1,type:water,cost:20;'\
                       'border=edge:3,type:water,cost:20',
            ['K9'] => 'city=revenue:0;border=edge:2,type:water,cost:20;border=edge:3,type:water,cost:20',
            ['D24'] => 'city=revenue:0;border=edge:3,type:water,cost:20;'\
                       'border=edge:2,type:water,cost:20',
            %w[H38 J6 J30] => 'city=revenue:0;border=edge:4,type:water,cost:20;'\
                              'border=edge:3,type:water,cost:20;border=edge:2,type:water,cost:20',
            ['F40'] => 'city=revenue:0;border=edge:4,type:water,cost:20;'\
                       'border=edge:3,type:water,cost:20;border=edge:5,type:water,cost:20',
            ['B38'] => 'city=revenue:0;city=revenue:0;label=OO;'\
                       'border=edge:4,type:water,cost:20;border=edge:5,type:water,cost:20',
            %w[H34 B28] => 'city=revenue:0;border=edge:4,type:water,cost:20;'\
                           'border=edge:5,type:water,cost:20;border=edge:0,type:water,cost:20',
            ['D4'] => 'city=revenue:0;label=B;border=edge:5,type:water,cost:20',
            ['H42'] => 'city=revenue:0;city=revenue:0;label=OO;'\
                       'border=edge:5,type:water,cost:20;border=edge:0,type:water,cost:20;'\
                       'border=edge:1,type:water,cost:20',
            ['C11'] => 'city=revenue:0;border=edge:5,type:water,cost:20;'\
                       'border=edge:4,type:water,cost:20',
          },
          yellow: {
            ['F4'] => 'city=revenue:10,groups:Denver;city=revenue:10,groups:Denver;'\
                      'city=revenue:10,groups:Denver;city=revenue:10,groups:Denver;path=a:0,b:_0;'\
                      'path=a:3,b:_1;path=a:4,b:_2;path=a:5,b:_3;label=Den',
            ['F36'] => 'city=revenue:30;path=a:1,b:_0;path=a:4,b:_0',
            ['K33'] => 'city=revenue:30;border=edge:1,type:water,cost:20;path=a:1,b:_0;path=a:2,b:_0',
          },
          gray: {
            %w[A5 A39] => 'offboard=revenue:0;path=a:0,b:_0',
            %w[B2 D2 H2] => 'offboard=revenue:0;path=a:4,b:_0',
            %w[A9 A19 A27 A37 A41] => 'path=a:0,b:5',
            %w[D42 F44] => 'path=a:0,b:1',
            %w[C43] => 'path=a:1,b:2',
            %w[G3 G43] => 'path=a:3,b:5',
            %w[K3] => 'path=a:3,b:4',
            %w[L18 L22] => 'path=a:2,b:3;border=edge:2,type:water,cost:20;border=edge:3,type:water,cost:20',
            %w[L14] => 'border=edge:3,type:water',
            %w[L16 L20 L24] => 'offboard=revenue:0;path=a:2,b:_0;border=edge:2,type:water,cost:20;border=edge:3,type:water',
            %w[I43 L26] => 'path=a:2,b:3;border=edge:2,type:water,cost:20',
            %w[L8 L34] => 'path=a:2,b:3',
            %w[J40] => 'path=a:2,b:3;path=a:1,b:3',
          },
          red: {
            %w[A3 E3] => 'label=W;offboard=revenue:yellow_30|green_40|brown_50|gray_60,groups:West;path=a:5,b:_0',
            ['B42'] => 'label=E;offboard=revenue:yellow_30|green_50|brown_60|gray_80,groups:East;'\
                       'path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:5,b:_0',
            ['C3'] => 'label=W;offboard=revenue:yellow_30|green_40|brown_50|gray_60,groups:West;path=a:4,b:_0;path=a:5,b:_0',
            ['I3'] => 'label=W;offboard=revenue:yellow_30|green_40|brown_50|gray_60,groups:West;path=a:3,b:_0;'\
                      'path=a:4,b:_0;path=a:5,b:_0',
            ['H44'] => 'label=E;offboard=revenue:yellow_30|green_50|brown_60|gray_80,groups:East;path=a:0,b:_0;path=a:1,b:_0;'\
                       'path=a:2,b:_0',
          },
        }.freeze
      end
    end
  end
end
