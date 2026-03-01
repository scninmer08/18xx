# frozen_string_literal: true

module View
  module Game
    module Part
      class HalfFill < Snabberb::Component
        include Lib::Settings

        needs :tile
        needs :region_use, default: nil

        def render
          frame = @tile.frame
          return empty unless frame&.color
          part = @tile.partitions.first
          return empty unless part

          a_loc, b_loc, mode = extract_partition_locs(part)
          base_color = frame.color
          half_color = frame.color2 || frame.color

          pts  = hex_points(@tile.hex.layout)
          a_pt = point_for_loc(pts, a_loc)
          b_pt = point_for_loc(pts, b_loc)

          # walk CCW around the hex to build the overlay half polygon
          start_idx = next_vertex_after(a_loc)
          end_idx   = last_vertex_before_or_at(b_loc)
          half_ring = [a_pt] + arc_vertices(pts, start_idx, end_idx) + [b_pt]

          full_hex_path = path_from(pts)
          half_path     = path_from(half_ring)

          base_props = {
            attrs: {
              d: full_hex_path,
              fill: color_for(base_color),
              stroke: 'none',
              'shape-rendering': 'crispEdges',
            },
          }
          half_props = {
            attrs: {
              d: half_path,
              fill: color_for(half_color),
              stroke: 'none',
              'shape-rendering': 'crispEdges',
              # optional: tag how it was interpreted for debugging
              'data-split-mode': mode,
            },
          }

          h(:g, [h(:path, base_props), h(:path, half_props)])
        end

        private

        def empty = h(:g)

        # --- data extraction -------------------------------------------------

        def extract_partition_locs(part)
          # Try to pull decimal a/b directly from the original code string
          code = @tile.respond_to?(:code) ? @tile.code.to_s : ''
          if (m = code.match(/partition=([^;]+)/))
            kv = Hash[m[1].split(',').map { |p| p.split(':', 2) }]
            a = kv['a']&.to_f
            b = kv['b']&.to_f
            t = (kv['type'] || part.type.to_s)
            if a && b
              # Optional “vertex mode”: allow integer a/b to mean “vertex after edge”
              if t.include?('vertex') && (a % 1.0).zero? && (b % 1.0).zero?
                a += 0.5
                b += 0.5
              end
              return [normalize_loc(a), normalize_loc(b), 'from_code']
            end
          end

          # Fallback to the partition object (likely ints)
          a = part.a.to_f
          b = part.b.to_f
          t = part.type.to_s
          if t.include?('vertex') && (a % 1.0).zero? && (b % 1.0).zero?
            a += 0.5
            b += 0.5
          end
          [normalize_loc(a), normalize_loc(b), 'from_part']
        end

        # rotate and wrap to [0,6) without rounding
        def normalize_loc(raw) = ((raw.to_f + @tile.rotation) % 6.0)

        # --- geometry --------------------------------------------------------

        def hex_points(layout)
          r = 100.0
          rt3_2 = Math.sqrt(3) / 2.0
          if layout == :pointy
            [
              [ 0.0,   -r       ],
              [ r*rt3_2, -0.5*r ],
              [ r*rt3_2,  0.5*r ],
              [ 0.0,     r       ],
              [-r*rt3_2,  0.5*r ],
              [-r*rt3_2, -0.5*r ],
            ]
          else # :flat
            [
              [ r,     0.0     ],
              [ 0.5*r,  r*rt3_2],
              [-0.5*r,  r*rt3_2],
              [-r,      0.0    ],
              [-0.5*r, -r*rt3_2],
              [ 0.5*r, -r*rt3_2],
            ]
          end
        end

        def midpoint(p, q) = [(p[0] + q[0]) * 0.5, (p[1] + q[1]) * 0.5]

        # loc in [0,6):
        #  - integer → edge midpoint
        #  - .5      → vertex (the “next” vertex)
        def point_for_loc(pts, loc)
          i = loc.floor % 6
          f = loc - i
          v_i   = pts[i]
          v_ip1 = pts[(i + 1) % 6]
          return midpoint(v_i, v_ip1) if near?(f, 0.0)
          return v_ip1                 if near?(f, 0.5)
          # snap: closer to midpoint if near 0/1, else to vertex
          (f < 0.25 || f > 0.75) ? midpoint(v_i, v_ip1) : v_ip1
        end

        def next_vertex_after(loc) = (loc.floor + 1) % 6

        def last_vertex_before_or_at(loc)
          f = loc - loc.floor
          near?(f, 0.0) ? (loc.to_i % 6) : ((loc.floor + 1) % 6)
        end

        def arc_vertices(pts, i, j)
          res = []
          k = i
          loop do
            res << pts[k]
            break if k == j
            k = (k + 1) % 6
          end
          res
        end

        # keep full float precision; no rounding
        def path_from(points)
          'M ' + points.map { |x, y| "#{x} #{y}" }.join(' L ') + ' Z'
        end

        def near?(a, b, eps = 1e-9) = (a - b).abs < eps
      end
    end
  end
end
