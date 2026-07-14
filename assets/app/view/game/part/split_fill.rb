# frozen_string_literal: true

require 'lib/hex'

module View
  module Game
    module Part
      class SplitFill < Snabberb::Component
        needs :tile
        needs :region_use, default: nil

        FLAT_VERTICES = [
          [Lib::Hex::X_M_R, Lib::Hex::Y_B],
          [Lib::Hex::X_M_L, Lib::Hex::Y_B],
          [Lib::Hex::X_L, Lib::Hex::Y_M],
          [Lib::Hex::X_M_L, Lib::Hex::Y_T],
          [Lib::Hex::X_M_R, Lib::Hex::Y_T],
          [Lib::Hex::X_R, Lib::Hex::Y_M],
        ].freeze

        def render
          frame = @tile.frame
          partition = @tile.partitions.find { |part| part.type == 'split' }
          return h(:g) unless frame&.color && partition

          point_a = FLAT_VERTICES[partition.a]
          point_b = FLAT_VERTICES[partition.b]
          half_ab = [point_a] + clockwise_arc(partition.a, partition.b) + [point_b]
          half_ba = [point_b] + clockwise_arc(partition.b, partition.a) + [point_a]

          primary = tile_color(frame.color)
          secondary = tile_color(frame.color2 || frame.color)
          ab_fill, ba_fill = original_a_greater_than_b? ? [primary, secondary] : [secondary, primary]

          h(:g, [
            h(:path, attrs: { d: path(half_ba), fill: ba_fill, stroke: 'none' }),
            h(:path, attrs: { d: path(half_ab), fill: ab_fill, stroke: 'none' }),
          ])
        end

        private

        def clockwise_arc(from, to)
          result = []
          index = (from + 1) % 6
          while index != to
            result << FLAT_VERTICES[index]
            index = (index + 1) % 6
          end
          result
        end

        # Partition normalizes a/b with minmax, so consult the source code to
        # retain which frame color belongs on each side of the original split.
        def original_a_greater_than_b?
          match = @tile.code.to_s.match(/\bpartition=[^;]*\ba:([\d.]+)[^;]*\bb:([\d.]+)/)
          match && match[1].to_f > match[2].to_f
        end

        def path(points)
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
