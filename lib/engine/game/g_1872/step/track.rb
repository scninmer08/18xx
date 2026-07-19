# frozen_string_literal: true

require_relative '../../../step/track'

module Engine
  module Game
    module G1872
      module Step
        class Track < Engine::Step::Track
          def potential_tiles(entity_or_entities, hex)
            tiles = super
            return tiles if palmer_greenwood_available?(track_corporation(entity_or_entities))

            tiles.reject { |tile| tile.name == '8' }
          end

          def lay_tile_action(action, entity: nil, spender: nil)
            palmer_greenwood = nil
            if action.tile.name == '8'
              corporation = track_corporation(entity || action.entity)
              palmer_greenwood = @game.company_by_id('PGS')

              unless palmer_greenwood_available?(corporation)
                raise GameError, 'Tile #8 may only be laid by the owner of Palmer-Greenwood Survey'
              end
            end

            super

            return unless palmer_greenwood

            @game.company_closing_after_using_ability(palmer_greenwood)
            palmer_greenwood.close!
          end

          def extra_cost(tile, tile_lay, hex)
            return 20 if town_upgrade?(hex.tile, tile)

            super
          end

          def legal_tile_rotation?(entity_or_entities, hex, tile)
            return super unless town_upgrade?(hex.tile, tile)

            old_exits = hex.tile.exits
            new_exits = tile.exits
            (old_exits - new_exits).empty? &&
              new_exits.size == old_exits.size + 1 &&
              tile.towns.one? &&
              new_exits.all? { |edge| hex.neighbors[edge] }
          end

          private

          def palmer_greenwood_available?(corporation)
            palmer_greenwood = @game.company_by_id('PGS')
            palmer_greenwood && !palmer_greenwood.closed? && palmer_greenwood.owner == corporation
          end

          def track_corporation(entity_or_entities)
            entities = Array(entity_or_entities)
            entity = entities.find(&:corporation?) || entities.first
            entity = entity.owner if entity&.company?
            entity
          end

          def town_upgrade?(old_tile, new_tile)
            old_tile.name == '9' && %w[141 142].include?(new_tile.name)
          end
        end
      end
    end
  end
end
