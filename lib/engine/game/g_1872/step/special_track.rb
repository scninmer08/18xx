# frozen_string_literal: true

require_relative '../../../step/special_track'

module Engine
  module Game
    module G1872
      module Step
        class SpecialTrack < Engine::Step::SpecialTrack
          def actions(entity)
            return [] if entity.id == 'BCLC' && hays_laid?

            super
          end

          def process_lay_tile(action)
            big_creek = action.entity.id == 'BCLC' ? action.entity : nil
            super
            return unless big_creek

            @game.mines_connection_changed!
            @game.remove_connected_unauctioned_land_grants!
            @game.use_big_creek_land_company!(big_creek.owner, city: action.hex.tile.cities.first)
          end

          def potential_tiles(entity_or_entities, hex)
            tiles = super
            return tiles if Array(entity_or_entities).first&.id == 'PGS'

            tiles.reject { |tile| tile.name == '8' }
          end

          private

          def hays_laid?
            @game.hex_by_id('H26').tile.color != :white
          end
        end
      end
    end
  end
end
