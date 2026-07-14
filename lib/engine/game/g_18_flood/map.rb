# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Map
        LAYOUT = :flat

        CENTER_CITY = ['K21'].freeze
        INNER_PLAIN_HEXES = %w[J18 L18 M21 L24 J24 I21].freeze

        STEEL_MILLS  = %w[G17 O17 K29].freeze
        LUMBER_MILLS = %w[E15 Q15 K33].freeze
        HOME_HEXES = %w[F26 K11 P26].freeze
        FORMER_HOME_HEXES = %w[E27 K9 Q27].freeze
        VERTEX_WATER_HEXES = %w[D14 R14 K35 E29 D28 D26 J8 K7 L8 Q29 R26 R28].freeze

        RADIUS1 = %w[J20 K19 L20 L22 K23 J22].freeze
        RADIUS2 = %w[I19 I23 K17 K25 M19 M23].freeze
        RADIUS3 = %w[H18 I17 J16 L16 M17 N18 N20 N22 M25 L26 K27 J26 I25 H22 H20].freeze
        RADIUS4 = %w[H16 I15 J14 K13 L14 M15 N16 O19 O21 O23 O25 N26 M27 L28 J28 I27 H26 G25 G23 G21 G19].freeze
        RADIUS5 = %w[F16 G15 H14 I13 J12 K11 L12 M13 N14 O15 P16 P18 P20 P22 P24 P26 N28 O27 M29 L30 K31 J30 I29 H28 G27 F26 F24
                     F22 F20 F18].freeze
        RADIUS6 = %w[F14 G13 H12 I11 J10 L10 M11 N12 O13 P14 Q17 Q19 Q21 Q23 Q25 P28 O29 N30 M31 L32 J32 I31 H30 G29 F28 E25 E23 E21
                     E19 E17].freeze
        RADIUS7 = %w[D14 E13 F12 G11 H10 I9 J8 K7 L8 M9 N10 O11 P12 Q13 R14 R16 R18 R20 R22 R24 R26 R28 Q29 P30 O31 N32 M33 L34 K35
                     J34 I33 H32 G31 F30 E29 D28 D26 D24 D22 D20 D18 D16].freeze
        RADIUS8 = %w[C13 D12 E11 F10 G9 H8 I7 K5 M7 N8 O9 P10 Q11 R12 S13 S15 S17 S19 S21 S23 S25 S29 Q31 P32 O33 N34 M35 L36 K37 J36
                     I35 H34 G33 F32 E31 C29 C25 C23 C21 C19 C17 C15].freeze
        RADIUS9 = %w[B12 C11 D10 E9 F8 G7 H6 I5 J4 K3 L4 M5 N6 O7 P8 Q9 R10 S11 T12 T14 T16 T18 T20 T22 T24 T26 T28 T30 S31 R32 Q33
                     P34 O35 N36 M37 L38 K39 J38 I37 H36 G35 F34 E33 D32 C31 B30 B28 B26 B24 B22 B20 B18 B16 B14].freeze

        def all_rings
          @all_rings ||= [RADIUS1, RADIUS2, RADIUS3, RADIUS4, RADIUS5, RADIUS6, RADIUS7, RADIUS8, RADIUS9]
        end

        def all_hex_ids
          @all_hex_ids ||= all_rings.flatten(1) | CENTER_CITY | INNER_PLAIN_HEXES
        end

        def game_hexes
          hexes = {
            white: {
              RADIUS2 => 'upgrade=cost:240,terrain:mountain;',
              INNER_PLAIN_HEXES => 'upgrade=cost:240,terrain:mountain;',
              RADIUS3 => 'upgrade=cost:120,terrain:mountain;',
              RADIUS4 => 'upgrade=cost:120,terrain:mountain;',
              (RADIUS5 - HOME_HEXES) => 'upgrade=cost:60,terrain:mountain;',
              RADIUS6 => 'upgrade=cost:60,terrain:mountain;',
              FORMER_HOME_HEXES => 'upgrade=cost:60,terrain:mountain;',
              RADIUS7 => 'upgrade=cost:60,terrain:mountain;',
              RADIUS8 => 'upgrade=cost:60,terrain:mountain;',
              RADIUS9 => 'upgrade=cost:60,terrain:mountain;',
              ['K15'] => 'frame=color:brown,color2:gray;' \
                         'partition=a:2.5,b:5.5,type:split;' \
                         'icon=image:mine,name:steel,sticky:1,loc:2.5;' \
                         'icon=image:tree,name:lumber,sticky:1,loc:5.5;' \
                         'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',

              ['H24'] => 'frame=color:brown,color2:gray;' \
                         'partition=a:0.5,b:3.5,type:split;' \
                         'icon=image:mine,name:steel,sticky:1,loc:0.5;' \
                         'icon=image:tree,name:lumber,sticky:1,loc:3.5;' \
                         'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',

              ['N24'] => 'frame=color:brown,color2:gray;' \
                         'partition=a:4.5,b:1.5,type:split;' \
                         'icon=image:mine,name:steel,sticky:1,loc:4.5;' \
                         'icon=image:tree,name:lumber,sticky:1,loc:1.5;' \
                         'offboard=revenue:0;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0',
            },
            yellow: {
              ['J20'] => 'city=revenue:20;city=revenue:20;path=a:2,b:_0;path=a:5,b:_1;upgrade=cost:160,terrain:mountain;',
              ['K19'] => 'city=revenue:20;city=revenue:20;path=a:3,b:_0;path=a:0,b:_1;upgrade=cost:160,terrain:mountain;',
              ['L20'] => 'city=revenue:20;city=revenue:20;path=a:4,b:_0;path=a:1,b:_1;upgrade=cost:160,terrain:mountain;',
              ['L22'] => 'city=revenue:20;city=revenue:20;path=a:5,b:_0;path=a:2,b:_1;upgrade=cost:160,terrain:mountain;',
              ['K23'] => 'city=revenue:20;city=revenue:20;path=a:0,b:_0;path=a:3,b:_1;upgrade=cost:160,terrain:mountain;',
              ['J22'] => 'city=revenue:20;city=revenue:20;path=a:1,b:_0;path=a:4,b:_1;upgrade=cost:160,terrain:mountain;',
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
              HOME_HEXES => 'city=revenue:80;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;'\
                         'path=a:4,b:_0;path=a:5,b:_0;',
            },
          }

          hexes[:blue] = { outer_water_ring => '' }
          mask = generated_shape_mask
          return hexes if mask.empty?

          hexes.each_with_object({}) do |(color, definitions), result|
            if color == :blue
              result[color] = definitions
            else
              result[color] = definitions.each_with_object({}) do |(coordinates, code), filtered|
                remaining = Array(coordinates) - mask
                filtered[remaining] = code unless remaining.empty?
              end
            end
          end
        end

        def generated_shape_mask
          return [] if @optional_rules&.include?(:symmetrical_map)

          @generated_shape_mask ||= (RADIUS7 + RADIUS8 + RADIUS9).uniq.freeze
        end

        def neighbor_coordinate_ids(id)
          x, y = Engine::Hex.init_x_y(id, nil).first(2)
          Engine::Hex::DIRECTIONS[:flat].keys.filter_map do |dx, dy|
            nx = x + dx
            ny = y + dy
            next if nx.negative? || ny.negative? || nx >= Engine::Hex::LETTERS.size

            "#{Engine::Hex::LETTERS[nx]}#{ny + 1}"
          end
        end

        def outer_water_ring
          @outer_water_ring ||= begin
            if @optional_rules&.include?(:symmetrical_map)
              boundary = RADIUS9
              existing = all_rings.flatten | CENTER_CITY | STEEL_MILLS | LUMBER_MILLS |
                         INNER_PLAIN_HEXES | HOME_HEXES | FORMER_HOME_HEXES |
                         %w[K15 H24 N24 J20 K19 L20 L22 K23 J22]
            else
              boundary = RADIUS6 + FORMER_HOME_HEXES
              existing = [RADIUS1, RADIUS2, RADIUS3, RADIUS4, RADIUS5, RADIUS6].flatten |
                         CENTER_CITY | INNER_PLAIN_HEXES | STEEL_MILLS | LUMBER_MILLS |
                         HOME_HEXES | FORMER_HOME_HEXES | %w[K15 H24 N24 J20 K19 L20 L22 K23 J22]
            end
            water = boundary.flat_map { |id| neighbor_coordinate_ids(id) }
                            .uniq
                            .reject { |id| existing.include?(id) }
            unless @optional_rules&.include?(:symmetrical_map)
              vertex_water = FORMER_HOME_HEXES.flat_map { |id| neighbor_coordinate_ids(id) }
                                              .reject { |id| existing.include?(id) }
              water |= vertex_water
              water |= VERTEX_WATER_HEXES
            end
            water.freeze
          end
        end
      end
    end
  end
end
