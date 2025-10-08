# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18FLOOD
      module Step
        class ResourceDelivery < Engine::Step::Base
          ACTIONS = %w[choose].freeze

          def round_state
            super.merge(resource_delivery_done: {})
          end

          def description = 'Resource Delivery'

          def actions(entity)
            return [] if entity != current_entity
            return [] unless @game.national_corporation?(entity)
            return [] if delivered?(entity)
            ACTIONS
          end

          def auto_actions(entity)
            return [] unless actions(entity).any?
            [Engine::Action::Choose.new(entity, choice: 'gen')]
          end

          def active?
            !active_entities.empty?
          end

          def active_entities
            corp = @round.current_operator
            return [] if corp.nil? || !@game.national_corporation?(corp) || delivered?(corp)
            [corp]
          end

          def choices
            { 'gen' => 'Deliver resources along placed track' }
          end

          def choice_name = 'Resource Delivery'

          def choice_available?(entity)
            entity == current_entity && !delivered?(entity)
          end

          def log_skip(entity)
            return if @game.shell_corporation?(entity)
            super
          end

          def process_choose(action)
            corp  = action.entity
            graph = @game.graph_for_entity(corp)

            edges_by_hex = Hash.new { |h, k| h[k] = [] }
            corp.tokens.each do |tok|
              city = tok.city
              next unless city
              (graph.connected_hexes_by_token(corp, city) || {}).each do |hex, edges|
                next if hex.nil? || edges.nil?
                arr = edges_by_hex[hex.id]
                Array(edges).each { |e| arr << e unless arr.include?(e) }
              end
            end

            lumber_routes = 0
            steel_routes  = 0

            lumber_hex_ids = @game.class::LUMBER_MILLS
            steel_hex_ids  = @game.class::STEEL_MILLS

            edges_by_hex.each do |hid, touched|
              next if touched.empty?

              if lumber_hex_ids.include?(hid)
                lumber_routes += touched.size
                next
              end

              if steel_hex_ids.include?(hid)
                steel_routes += touched.size
                next
              end

              hex  = @game.hex_by_id(hid)
              tile = hex&.tile
              next unless tile

              halves = split_halves(tile)
              next unless halves

              per_resource = map_halves_to_resources(tile, halves)
              l_allowed = per_resource[:lumber] || []
              s_allowed = per_resource[:steel]  || []

              lumber_routes += touched.count { |e| l_allowed.include?(e) }
              steel_routes  += touched.count { |e| s_allowed.include?(e) }
            end

            @game.lumber[corp] += lumber_routes
            @game.steel[corp]  += steel_routes
            @log << "#{corp.name} receives #{lumber_routes} lumber and #{steel_routes} steel"

            @round.resource_delivery_done[corp.id] = true
          end

          private

          def delivered?(corp)
            !!@round.resource_delivery_done[corp.id]
          end

          def split_halves(tile)
            part = tile.partitions&.first
            return nil unless part && part.type == :split

            a = to_f(part.a)
            b = to_f(part.b)

            half_a = edges_on_arc(a, b)
            half_b = ([0, 1, 2, 3, 4, 5] - half_a)
            [half_a.sort, half_b.sort]
          end

          def map_halves_to_resources(tile, halves)
            frame = tile.frame
            if frame
              c1 = frame.color.to_s.downcase
              c2 = frame.color2.to_s.downcase
              if c1 == 'brown' && c2 == 'gray'
                return { lumber: halves[0], steel: halves[1] }
              elsif c1 == 'gray' && c2 == 'brown'
                return { lumber: halves[1], steel: halves[0] }
              end
            end
            { lumber: halves[0], steel: halves[1] }
          end

          def edges_on_arc(a, b)
            start = a.ceil % 6
            stop  = b.floor % 6
            res = []
            i = start
            loop do
              res << i
              break if i == stop
              i = (i + 1) % 6
            end
            res
          end

          def to_f(v)
            v.is_a?(String) ? v.to_f : v.to_f
          end
        end
      end
    end
  end
end
