# frozen_string_literal: true

require_relative '../../g_18_il/step/track'
require_relative '../../../action/lay_tile'

module Engine
  module Game
    module G18IlSolo
      module Step
        class Track < G18IL::Step::Track
          CHI_HEX = 'H3'.freeze
          CHI_NEXT = {
            yellow: ['CHI2', :green],
            green: ['CHI3', :brown],
            brown: ['CHI4', :gray],
          }.freeze

          def actions(entity)
            return [] if entity.owner == @game.robot

            super
          end

          def skip!
            entity = current_entity
            auto_upgrade_chicago_for_ic(entity) if entity == @game.ic
            super
          end

          def log_skip(entity)
            return if entity.owner == @game.robot

            super
          end

          private

          def auto_upgrade_chicago_for_ic(ic)
            hex = @game.hex_by_id(CHI_HEX)
            return if hex.nil? || (old = hex.tile).nil?

            next_name, required_color = CHI_NEXT[old.color]
            return unless next_name
            return unless @game.phase.tiles.include?(required_color)

            tile = @game.tiles.find { |t| t.name == next_name }
            return unless tile
            return unless @game.upgrades_to?(old, tile, false)

            action = Engine::Action::LayTile.new(ic, hex: hex, tile: tile, rotation: 0)

            process_lay_tile(action)
          end
        end
      end
    end
  end
end
