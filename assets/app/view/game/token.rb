# frozen_string_literal: true

require 'lib/settings'

module View
  module Game
    class Token < Snabberb::Component
      include Lib::Settings

      needs :game
      needs :token
      needs :radius
      needs :user, default: nil, store: true

      RED_WIDTH = 7
      WHITE_WIDTH = 2
      ISOLATED_COLOR = '#f2a900'
      ISOLATED_RING_WIDTH = 3

      def render
        overlay =
          case @token.status
          when :flipped
            render_flipped_stroke
          when :isolated
            render_isolated_overlay
          else
            []
          end

        return render_token if overlay.empty?

        h(:g, [render_token, *overlay])
      end

      def render_token
        h(
          :image, attrs: {
            href: setting_for(:simple_logos, @game) ? @token.simple_logo : @token.logo,
            x: -@radius,
            y: -@radius,
            height: (2 * @radius),
            width: (2 * @radius),
          },
        )
      end

      def render_flipped_stroke
        s = (@radius / Math.sqrt(2)).round(2)
        d = ((RED_WIDTH + WHITE_WIDTH) / 2.0 / Math.sqrt(2)).round(2)
        [
          h(
            :path, attrs: {
              d: "M #{s} #{-s} L #{-s} #{s}",
              stroke: 'red',
              'stroke-width': RED_WIDTH,
              'stroke-opacity': '0.6',
            },
          ),
          h(
            :path, attrs: {
              d: "M #{s - d} #{-s - d} L #{-s - d} #{s - d}",
              stroke: 'white',
              'stroke-width': WHITE_WIDTH,
              'stroke-opacity': '1.0',
            },
          ),
          h(
            :path, attrs: {
              d: "M #{s + d} #{-s + d} L #{-s + d} #{s + d}",
              stroke: 'white',
              'stroke-width': WHITE_WIDTH,
              'stroke-opacity': '1.0',
            },
          ),
        ]
      end

      def render_isolated_overlay
        ring_radius = (@radius - (ISOLATED_RING_WIDTH / 2.0)).round(2)
        badge_x = (@radius * 0.55).round(2)
        badge_y = -badge_x
        badge_radius = (@radius * 0.28).round(2)
        icon_outer = (badge_radius * 0.58).round(2)
        icon_gap = (badge_radius * 0.18).round(2)
        icon_width = (badge_radius * 0.3).round(2)

        [
          h(
            :circle, attrs: {
              cx: 0,
              cy: 0,
              r: ring_radius,
              fill: 'none',
              stroke: 'white',
              'stroke-width': ISOLATED_RING_WIDTH + 2,
              'stroke-opacity': 0.85,
            },
          ),
          h(
            :circle, attrs: {
              cx: 0,
              cy: 0,
              r: ring_radius,
              fill: 'none',
              stroke: ISOLATED_COLOR,
              'stroke-width': ISOLATED_RING_WIDTH,
              'stroke-dasharray': '4 3',
            },
          ),
          h(
            :circle, attrs: {
              cx: badge_x,
              cy: badge_y,
              r: badge_radius,
              fill: ISOLATED_COLOR,
              stroke: 'white',
              'stroke-width': 1.5,
            },
          ),
          h(
            :path, attrs: {
              d: "M #{badge_x - icon_outer} #{badge_y + icon_outer} "\
                 "L #{badge_x - icon_gap} #{badge_y + icon_gap} "\
                 "M #{badge_x + icon_gap} #{badge_y - icon_gap} "\
                 "L #{badge_x + icon_outer} #{badge_y - icon_outer}",
              fill: 'none',
              stroke: '#332400',
              'stroke-width': icon_width,
              'stroke-linecap': 'round',
            },
          ),
        ]
      end
    end
  end
end
