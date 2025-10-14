# frozen_string_literal: true

require_relative '../../g_18_il/step/token'

module Engine
  module Game
    module G18IlSolo
      module Step
        class Token < G18IL::Step::Token
          def actions(entity)
            return [] if entity.owner == @game.robot

            super
          end

          def skip!
            entity = current_entity
            if entity && auto_token_entity?(entity) && (auto = build_auto_token_action(entity))
              process_place_token(auto)
              return
            end
            super
          end

          def auto_actions(entity)
            return if entity.closed?
            return unless auto_token_entity?(entity)

            action = build_auto_token_action(entity)
            [action] || nil
          end

          private

          def auto_token_entity?(entity)
            (entity == @game.ic || @game.subsidiary?(entity)) &&
              entity == current_entity &&
              can_place_token?(entity) &&
              entity.tokens.any? { |t| !t.used }
          end

          def build_auto_token_action(entity)
            @game.token_targets_for(entity).each do |hex_id|
              hex = @game.hex_by_id(hex_id)
              next if hex.nil? || !available_hex(entity, hex)

              next unless (city, slot = first_tokenable_city_slot(entity, hex))

              # No :token here — the step will pick the correct one
              return Engine::Action::PlaceToken.new(entity, city: city, slot: slot)
            end
            nil
          end

          def first_tokenable_city_slot(entity, hex)
            if stl_token_hex?(hex)
              return nil unless stl_reachable?(entity)

              return [hex.tile.cities.first, 0]
            end

            hex.tile.cities.each_with_index do |city, idx|
              next unless city.tokenable?(entity)
              next unless @game.token_graph_for_entity(entity).connected_nodes(entity)[city]

              return [city, idx]
            end

            nil
          end
        end
      end
    end
  end
end
