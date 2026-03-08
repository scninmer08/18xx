# frozen_string_literal: true

require 'lib/hex'

module View
  module Game
    module Part
      class SplitFill < Snabberb::Component
        needs :tile
        needs :region_use, default: nil

        # Flat-hex vertices in clockwise order starting from bottom-right.
        # Matches Lib::Hex constants and Engine::Part::Partition vertex numbering.
        FLAT_VERTS = [
          [Lib::Hex::X_M_R, Lib::Hex::Y_B],  # 0: bottom-right
          [Lib::Hex::X_M_L, Lib::Hex::Y_B],  # 1: bottom-left
          [Lib::Hex::X_L,   Lib::Hex::Y_M],  # 2: left
          [Lib::Hex::X_M_L, Lib::Hex::Y_T],  # 3: top-left
          [Lib::Hex::X_M_R, Lib::Hex::Y_T],  # 4: top-right
          [Lib::Hex::X_R,   Lib::Hex::Y_M],  # 5: right
        ].freeze

        def render
          frame = @tile.frame
          return h(:g) unless frame&.color

          part = @tile.partitions.find { |p| p.type == 'split' }
          return h(:g) unless part

          pa = FLAT_VERTS[part.a]
          pb = FLAT_VERTS[part.b]

          # Build the two half-polygons by walking clockwise around the hex.
          half_ab = [pa] + clockwise_arc(part.a, part.b) + [pb]
          half_ba = [pb] + clockwise_arc(part.b, part.a) + [pa]

          # Color convention: the a→b clockwise arc gets frame.color2 (secondary/steel).
          # However, Engine::Part::Partition sorts a/b with minmax, which can swap the
          # intended ordering. Detect this by comparing the original values in the code
          # string and flip the assignment if they were swapped.
          c1 = tile_color(frame.color)
          c2 = tile_color(frame.color2 || frame.color)
          ab_fill, ba_fill = original_a_gt_b? ? [c1, c2] : [c2, c1]

          h(:g, [
            h(:path, attrs: { d: path_d(half_ba), fill: ba_fill, stroke: 'none' }),
            h(:path, attrs: { d: path_d(half_ab), fill: ab_fill, stroke: 'none' }),
          ])
        end

        private

        # Vertices strictly between i and j going clockwise (exclusive of i and j).
        def clockwise_arc(i, j)
          result = []
          k = (i + 1) % 6
          while k != j
            result << FLAT_VERTS[k]
            k = (k + 1) % 6
          end
          result
        end

        # True when the partition's original 'a' value in the tile code string was
        # numerically greater than 'b'. Engine::Part::Partition uses minmax to sort
        # a and b, so when a > b in the source the two halves are swapped and the
        # color convention needs to be reversed.
        def original_a_gt_b?
          m = @tile.code.to_s.match(/\bpartition=[^;]*\ba:([\d.]+)[^;]*\bb:([\d.]+)/)
          m && m[1].to_f > m[2].to_f
        end

        def path_d(points)
          'M ' + points.map { |x, y| "#{x} #{y}" }.join(' L ') + ' Z'
        end

        def tile_color(name)
          key = name.to_s.tr('_', '-')
          fallback = Lib::Hex::COLOR[name.to_sym] || key
          "var(--tile-#{key}, var(--color-#{key}, #{fallback}))"
        end
      end
    end
  end
end
