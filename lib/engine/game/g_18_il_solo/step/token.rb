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
              # Just try it; if nothing feasible was found we won’t get here.
              process_place_token(auto) unless @game.last_set
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
              next if hex.nil?
              next unless available_hex(entity, hex)

              # Skip STL unless it’s actually placeable right now for this entity.
              if stl_token_hex?(hex)
                next unless stl_token_feasible?(entity, hex)
              end

              next unless (city, slot = first_tokenable_city_slot(entity, hex))
              return Engine::Action::PlaceToken.new(entity, city: city, slot: slot)
            end
            nil
          end

          # Pre-check specifically for STL so we don’t hit the hard raises in place_token.
          def stl_token_feasible?(entity, hex)
            return false unless stl_reachable?(entity)
            return false if @game.stl_permit?(entity) # already used STL permit

            city = hex.tile.cities.first
            # Slot open?
            return true if city.available_slots.to_i.positive?

            # Would we be forced to replace a flipped token? If yes, that’s feasible.
            flipped = hex.tile.cities.map { |c| c.tokens.find { |t| t&.status == :flipped } }.compact.first
            return true if should_replace_flipped_token?(entity, city, flipped)

            # Can we free an STLBC slot at the current phase?
            city.tokens.each_with_index.any? do |t, index|
              next false unless t&.corporation&.name == 'STLBC'
              case index
              when 0 then @game.phase.tiles.include?(:yellow)
              when 1 then @game.phase.tiles.include?(:green)
              when 2 then @game.phase.tiles.include?(:brown)
              when 3 then @game.phase.tiles.include?(:gray)
              else false
              end
            end
          end

          def first_tokenable_city_slot(entity, hex)
            if stl_token_hex?(hex)
              return nil unless stl_reachable?(entity)
              return nil if @game.stl_permit?(entity)
              # We always target city 0 for STL; place_token will handle freeing/replacing when legal.
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
