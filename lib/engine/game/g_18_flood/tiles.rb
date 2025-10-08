# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Tiles
        TILES = {
          '57' => 6,
          '608' => {
            'count' => 6,
            'color' => 'green',
            'code' => 'city=revenue:40;path=a:0,b:_0;path=a:3,b:_0;',
          },
          '799' => {
            'count' => 6,
            'color' => 'brown',
            'code' => 'city=revenue:60;path=a:0,b:_0;path=a:3,b:_0;',
          },
          'FLOOD' => {
            'count' => 'unlimited',
            'color' => 'blue',
            'code' => '',
          },
          'FLD21' => {
            'count' => 25,
            'color' => 'green',
            'code' => 'city=revenue:40;path=a:0,b:_0;path=a:1,b:_0;city=revenue:40;path=a:2,b:_1;path=a:4,b:_1;',
          },
          'FLD22' => {
            'count' => 25,
            'color' => 'green',
            'code' => 'city=revenue:40;path=a:0,b:_0;path=a:1,b:_0;city=revenue:40;path=a:3,b:_1;path=a:5,b:_1;',
          },
          'FLD31' => {
            'count' => 25,
            'color' => 'brown',
            'code' => 'city=revenue:60,loc:0;path=a:5,b:_0;path=a:0,b:_0;path=a:1,b:_0;city=revenue:40,loc:3;'\
                      'path=a:2,b:_1;path=a:3,b:_1;path=a:4,b:_1;',
          },
          'FLD41' => {
            'count' => 25,
            'color' => 'gray',
            'code' =>
            'city=revenue:60,loc:0;city=revenue:60,loc:3;path=a:0,b:_0;path=a:1,b:_0;path=a:5,b:_0;'\
            'path=a:2,b:_1;path=a:3,b:_1;path=a:4,b:_1;path=a:_0,b:_1;',
          },
          # center city
          'FLDS2' => {
            'count' => 10,
            'color' => 'green',
            'code' => 'city=revenue:60,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;'\
                      'path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=C;',
          },
          'FLDS3' => {
            'count' => 10,
            'color' => 'brown',
            'code' => 'city=revenue:90,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;'\
                      'path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=C;',
          },
          'FLDS4' => {
            'count' => 10,
            'color' => 'gray',
            'code' => 'city=revenue:120,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;'\
                      'path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=C;',
          },
          'FLDS5' => {
            'count' => 10,
            'color' => 'purple',
            'code' => 'city=revenue:150,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;'\
                      'path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=C;',
          },

          # simple track
          '7' => 50,
          '8' => 50,
          '9' => 50,
          '16' => 30,
          '17' => 30,
          '18' => 30,
          '19' => 30,
          '20' => 30,
          '21' => 30,
          '22' => 30,
        }.freeze
      end
    end
  end
end
