# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Map
        LAYOUT = :flat

        CENTER_CITY = ['J19'].freeze

        SINGLE_SLOT_CITIES = %w[I16 K16 L19 K22 I22 H19].freeze

        STEEL_MILLS  = %w[F15 N15 J27 C28 R25 I4].freeze
        LUMBER_MILLS = %w[D13 P13 J31 B25 Q28 K4].freeze

        RADIUS1 = %w[I18 J17 K18 K20 J21 I20].freeze
        RADIUS2 = %w[H17 H21 J15 J23 L17 L21].freeze
        RADIUS3 = %w[G16 H15 I14 K14 L15 M16 M18 M20 L23 K24 J25 I24 H23 G20 G18].freeze
        RADIUS4 = %w[G14 H13 I12 J11 K12 L13 M14 N17 N19 N21 N23 M24 L25 K26 I26 H25 G24 F23 F21 F19 F17].freeze
        RADIUS5 = %w[E14 F13 G12 H11 I10 J9 K10 L11 M12 N13 O14 O16 O18 O20 O22 O24 M26 N25 L27 K28 J29 I28 H27 G26 F25 E24 E22
                     E20 E18 E16].freeze
        RADIUS6 = %w[E12 F11 G10 H9 I8 K8 L9 M10 N11 O12 P15 P17 P19 P21 P23 O26 N27 M28 L29 K30 I30 H29 G28 F27 E26 D23 D21 D19
                     D17 D15].freeze
        RADIUS7 = %w[C12 D11 E10 F9 G8 H7 I6 J5 K6 L7 M8 N9 O10 P11 Q12 Q14 Q16 Q18 Q20 Q22 Q24 Q26 P27 O28 N29 M30 L31 K32 J33
                     I32 H31 G30 F29 E28 D27 C26 C24 C22 C20 C18 C16 C14].freeze
        RADIUS8 = %w[B11 C10 D9 E8 F7 G6 H5 J3 L5 M6 N7 O8 P9 Q10 R11 R13 R15 R17 R19 R21 R23 R27 P29 O30 N31 M32 L33 K34 J35 I34
                     H33 G32 F31 E30 D29 B27 B23 B21 B19 B17 B15 B13].freeze
        RADIUS9 = %w[A10 B9 C8 D7 E6 F5 G4 H3 I2 J1 K2 L3 M4 N5 O6 P7 Q8 R9 S10 S12 S14 S16 S18 S20 S22 S24 S26 S28 R29 Q30 P31
                     O32 N33 M34 L35 K36 J37 I36 H35 G34 F33 E32 D31 C30 B29 A28 A26 A24 A22 A20 A18 A16 A14 A12].freeze

        SEXTANT1 = %w[E12 F11 F13 G10 G14 H9 H11 H13 H15 I10 I12 I14].freeze
        SEXTANT2 = %w[O12 N11 N13 M10 M14 L9 L11 L13 L15 K10 K12 K14].freeze
        SEXTANT3 = %w[D15 D17 D19 D21 E16 E18 E20 E22 F17 F21 G18 G20].freeze
        SEXTANT4 = %w[P15 P17 P19 P21 O16 O18 O20 O22 N17 N21 M18 M20].freeze
        SEXTANT5 = %w[F25 F27 G24 G28 H23 H25 H27 H29 I24 I26 I28 I30].freeze
        SEXTANT6 = %w[N25 N27 M24 M28 L23 L25 L27 L29 K24 K26 K28 K30].freeze

        SEXTANTS = [SEXTANT1, SEXTANT2, SEXTANT3, SEXTANT4, SEXTANT5, SEXTANT6].freeze

        def all_rings
          @all_rings ||= [RADIUS1, RADIUS2, RADIUS3, RADIUS4, RADIUS5, RADIUS6, RADIUS7, RADIUS8, RADIUS9]
        end

        def all_hex_ids
          @all_hex_ids ||= all_rings.flatten(1) | CENTER_CITY
        end

        def game_hexes
          {
            white: {
              RADIUS2 => 'upgrade=cost:240,terrain:mountain;',
              RADIUS3 => 'upgrade=cost:240,terrain:mountain;',
              RADIUS4 => 'upgrade=cost:120,terrain:mountain;',
              RADIUS5 => 'upgrade=cost:120,terrain:mountain;',
              RADIUS6 => 'upgrade=cost:60,terrain:mountain;',
              RADIUS7 => 'upgrade=cost:60,terrain:mountain;',
              RADIUS8 => 'upgrade=cost:60,terrain:mountain;',
              RADIUS9 => 'upgrade=cost:60,terrain:mountain;',
              SINGLE_SLOT_CITIES => 'city=revenue:0;upgrade=cost:240,terrain:mountain;',
              ['J13'] => 'frame=color:brown,color2:gray;' \
                         'partition=a:2.5,b:5.5,type:split;' \
                         'icon=image:mine,name:steel,sticky:1,loc:2.5;' \
                         'icon=image:tree,name:lumber,sticky:1,loc:5.5;' \
                         'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',

              ['G22'] => 'frame=color:brown,color2:gray;' \
                         'partition=a:0.5,b:3.5,type:split;' \
                         'icon=image:mine,name:steel,sticky:1,loc:0.5;' \
                         'icon=image:tree,name:lumber,sticky:1,loc:3.5;' \
                         'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',

              ['M22'] => 'frame=color:brown,color2:gray;' \
                         'partition=a:4.5,b:1.5,type:split;' \
                         'icon=image:mine,name:steel,sticky:1,loc:4.5;' \
                         'icon=image:tree,name:lumber,sticky:1,loc:1.5;' \
                         'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',
            },
            yellow: {
              ['I18'] => 'city=revenue:20;city=revenue:20;path=a:2,b:_0;path=a:5,b:_1;upgrade=cost:240,terrain:mountain;',
              ['J17'] => 'city=revenue:20;city=revenue:20;path=a:3,b:_0;path=a:0,b:_1;upgrade=cost:240,terrain:mountain;',
              ['K18'] => 'city=revenue:20;city=revenue:20;path=a:4,b:_0;path=a:1,b:_1;upgrade=cost:240,terrain:mountain;',
              ['K20'] => 'city=revenue:20;city=revenue:20;path=a:5,b:_0;path=a:2,b:_1;upgrade=cost:240,terrain:mountain;',
              ['J21'] => 'city=revenue:20;city=revenue:20;path=a:0,b:_0;path=a:3,b:_1;upgrade=cost:240,terrain:mountain;',
              ['I20'] => 'city=revenue:20;city=revenue:20;path=a:1,b:_0;path=a:4,b:_1;upgrade=cost:240,terrain:mountain;',
              CENTER_CITY => 'city=revenue:30,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;'\
                             'path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=C;',
            },
            brown: {
              LUMBER_MILLS => 'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;'\
                              'path=a:4,b:_0;path=a:5,b:_0;icon=image:tree,name:lumber,sticky:1,loc:center',
            },
            gray: {
              STEEL_MILLS => 'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;'\
                             'path=a:4,b:_0;path=a:5,b:_0;icon=image:mine,name:steel,sticky:1,loc:center',
            },
            purple: {
              %w[D25 J7
                 P25] => 'city=revenue:80;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;'\
                         'path=a:4,b:_0;path=a:5,b:_0;',
            },
          }
        end
      end
    end
  end
end
