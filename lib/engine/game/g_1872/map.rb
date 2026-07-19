# frozen_string_literal: true

module Engine
  module Game
    module G1872
      module Map
        LAYOUT = :pointy

        TILES = {
          '8' => 1,
          '9' => 24,
          '53' => 2,
          '57' => 12,
          '59' => 2,
          '61' => 2,
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
          '205' => 6,
          '206' => 6,
          '235' => 2,
          '441' => 6,
          '442' => 6,
          '611' => 3,
          'X00' =>
          {
            'count' => 1,
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
          'C27' => 'Kearney',
          'C29' => 'Hastings',
          'C35' => 'Lincoln',
          'D4' => 'Greeley',
          'D24' => 'Holdrege',
          'D34' => 'Beatrice',
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
          'G41' => 'Leavenworth',
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

        HEXES = {
          white: {
            %w[B6 B8 B10 B24 B32 B34 B36 C5 C7 C9 C31 C33 C41 D14 D16 D18 D20 D28 D30 D32 D36
               E15 E17 E19 E23 E25 E27 E29 E31 E35 E37 F6 F8 F10 F12 F14 F16 F18 F20 F22 F26 F28 F30 F34
               F38 G5 G7 G9 G11 G15 G19 G21 G23 G25 G27 G29 G31 G33 G43 H6 H8 H10 H12 H14 H16 H18 H20 H22
               H24 H28 H30 I9 I11 I15 I17 I21 I23 I25 I37 J16 J18 J20 J22 J24 J34 J38 J40 K5 K29 K35
               K37 K39] => '',
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
            %w[D26 E11 I35] => 'border=edge:2,type:water,cost:20',
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
            %w[B4 C35 D34 E13 E21 E33 F36 G13 G17 H32 I19 J36 F24 F32 H4 I13] => 'city=revenue:0',
            ['H26'] => 'city=revenue:0;label=B',
            %w[B20 K19 K23] => 'city=revenue:0;border=edge:0,type:water,cost:20;'\
                               'border=edge:5,type:water,cost:20',
            ['K33'] => 'city=revenue:0;border=edge:1,type:water,cost:20',
            ['C27'] => 'city=revenue:0;border=edge:1,type:water,cost:20;border=edge:2,type:water,cost:20;'\
                       'border=edge:3,type:water,cost:20',
            ['C29'] => 'city=revenue:0;border=edge:2,type:water,cost:20',
            ['G41'] => 'city=revenue:0;border=edge:2,type:water,cost:20;border=edge:1,type:water,cost:20;'\
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
            ['D4'] => 'city=revenue:0;border=edge:5,type:water,cost:20',
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
          },
          gray: {
            %w[A5] => 'offboard=revenue:0;path=a:0,b:_0',
            %w[B2 D2 H2] => 'offboard=revenue:0;path=a:4,b:_0',
            %w[A9 A19 A27 A37 A39] => 'path=a:0,b:5',
            %w[D42 F44] => 'path=a:0,b:1',
            %w[C43] => 'path=a:1,b:2',
            %w[G3 K3] => 'path=a:3,b:4',
            %w[L18 L22] => 'path=a:2,b:3;border=edge:2,type:water,cost:20;border=edge:3,type:water,cost:20',
            %w[L14] => 'border=edge:3,type:water',
            %w[L16 L20 L24] => 'offboard=revenue:0;path=a:2,b:_0;border=edge:2,type:water,cost:20;border=edge:3,type:water',
            %w[I43 L26] => 'path=a:2,b:3;border=edge:2,type:water,cost:20',
            %w[L8 L34 L38] => 'path=a:2,b:3',
          },
          red: {
            ['A3'] => 'label=W;offboard=revenue:yellow_30|brown_50,groups:West;path=a:5,b:_0',
            ['B42'] => 'label=E;offboard=revenue:yellow_30|brown_50,groups:East;'\
                       'path=a:0,b:_0;path=a:1,b:_0;path=a:5,b:_0',
            ['C3'] => 'label=W;offboard=revenue:yellow_30|brown_50,groups:West;path=a:4,b:_0;path=a:5,b:_0',
            ['E3'] => 'label=W;offboard=revenue:yellow_30|brown_50,groups:West;path=a:5,b:_0',
            ['I3'] => 'label=W;offboard=revenue:yellow_30|brown_50,groups:West;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',
            ['H44'] => 'label=E;offboard=revenue:yellow_30|brown_50,groups:East;path=a:0,b:_0;path=a:1,b:_0;'\
                       'path=a:2,b:_0;border=edge:3;border=edge:5',
          },
        }.freeze
      end
    end
  end
end
