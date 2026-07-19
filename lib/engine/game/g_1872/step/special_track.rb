# frozen_string_literal: true

require_relative '../../../step/special_track'

module Engine
  module Game
    module G1872
      module Step
        class SpecialTrack < Engine::Step::SpecialTrack
          def potential_tiles(entity_or_entities, hex)
            tiles = super
            return tiles if Array(entity_or_entities).first&.id == 'PGS'

            tiles.reject { |tile| tile.name == '8' }
          end
        end
      end
    end
  end
end
