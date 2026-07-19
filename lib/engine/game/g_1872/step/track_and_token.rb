# frozen_string_literal: true

require_relative '../../../step/track_and_token'

module Engine
  module Game
    module G1872
      module Step
        class TrackAndToken < Engine::Step::TrackAndToken
          OO_HOME_CORPORATIONS = {
            'B38' => 'C&NW',
            'H42' => 'KATY',
          }.freeze

          def potential_tiles(entity_or_entities, hex)
            tiles = super
            corporation = track_corporation(entity_or_entities)
            tiles = tiles.reject do |tile|
              if single_slot_city_upgrade?(hex.tile, tile)
                !single_slot_city_upgrade_available?(corporation, hex)
              elsif city_slot_expansion_upgrade?(hex.tile, tile)
                !city_slot_expansion_upgrade_available?(corporation, hex)
              else
                mandatory_token_upgrade?(hex.tile, tile) && !upgrade_token_available?(corporation, hex)
              end
            end
            return tiles if palmer_greenwood_available?(corporation)

            tiles.reject { |tile| tile.name == '8' }
          end

          def lay_tile_action(action, entity: nil, spender: nil)
            palmer_greenwood = nil
            corporation = track_corporation(entity || action.entity)
            needs_upgrade_token =
              if single_slot_city_upgrade?(action.hex.tile, action.tile)
                validate_single_slot_city_upgrade!(corporation, action.hex)
                city_empty?(action.hex)
              elsif city_slot_expansion_upgrade?(action.hex.tile, action.tile)
                validate_city_slot_expansion_upgrade!(corporation, action.hex)
                true
              else
                mandatory_token_upgrade?(action.hex.tile, action.tile) &&
                  !corporation_tokened_in_hex?(corporation, action.hex)
              end
            validate_upgrade_token!(corporation, action.hex) if needs_upgrade_token

            if action.tile.name == '8'
              palmer_greenwood = @game.company_by_id('PGS')

              unless palmer_greenwood_available?(corporation)
                raise GameError, 'Tile #8 may only be laid by the owner of Palmer-Greenwood Survey'
              end
            end

            super

            place_upgrade_token!(corporation, action.hex) if needs_upgrade_token
            @game.assimilate_connected_shells!

            return unless palmer_greenwood

            @game.company_closing_after_using_ability(palmer_greenwood)
            palmer_greenwood.close!
          end

          def process_place_token(action)
            super
            @game.assimilate_connected_shells!
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

          def check_track_restrictions!(entity, old_tile, new_tile)
            return if green_city_slot_upgrade?(old_tile, new_tile)

            super
          end

          def available_hex(entity, hex)
            return false unless entity == current_entity
            return true if can_lay_tile?(entity) && tracker_available_hex(entity, hex)
            return false unless oo_home_token_placed?(hex)
            return true if can_place_token?(entity) && tokener_available_hex(entity, hex)

            false
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

          def mandatory_token_upgrade?(old_tile, new_tile)
            city_slot_expansion_upgrade?(old_tile, new_tile)
          end

          def single_slot_city_upgrade?(old_tile, new_tile)
            old_tile.name == '57' && %w[205 206].include?(new_tile.name)
          end

          def city_slot_expansion_upgrade?(old_tile, new_tile)
            direct_double_slot_upgrade?(old_tile, new_tile) || green_city_slot_upgrade?(old_tile, new_tile)
          end

          def direct_double_slot_upgrade?(old_tile, new_tile)
            old_tile.name == '57' && %w[441 442].include?(new_tile.name)
          end

          def green_city_slot_upgrade?(old_tile, new_tile)
            (old_tile.name == '205' && new_tile.name == '441') ||
            (old_tile.name == '206' && new_tile.name == '442')
          end

          def single_slot_city_upgrade_available?(corporation, hex)
            return false unless corporation
            return true if corporation_tokened_in_hex?(corporation, hex)
            return false unless city_empty?(hex)

            upgrade_token_available?(corporation, hex)
          end

          def city_slot_expansion_upgrade_available?(corporation, hex)
            return false unless corporation
            return false if corporation_tokened_in_hex?(corporation, hex)
            return false unless different_corporation_tokened_in_hex?(corporation, hex)

            upgrade_token_available?(corporation, hex)
          end

          def upgrade_token_available?(corporation, hex)
            return false unless corporation
            return true if corporation_tokened_in_hex?(corporation, hex)
            return false if @tokened
            return false if (tokens = available_tokens(corporation)).empty?

            min_token_price(tokens) <= buying_power(corporation)
          end

          def validate_single_slot_city_upgrade!(corporation, hex)
            return if corporation_tokened_in_hex?(corporation, hex) || city_empty?(hex)

            raise GameError, "#{corporation.name} cannot upgrade #{hex.name} to this tile because another corporation "\
                             'already has a token there'
          end

          def validate_city_slot_expansion_upgrade!(corporation, hex)
            if corporation_tokened_in_hex?(corporation, hex)
              raise GameError, "#{corporation.name} cannot lay this upgrade because it already has a token there"
            end

            return if different_corporation_tokened_in_hex?(corporation, hex)

            raise GameError, "#{hex.name} must contain another corporation's token to upgrade directly to this tile"
          end

          def validate_upgrade_token!(corporation, hex)
            raise GameError, "#{corporation.name} already placed a token this turn" if @tokened

            tokens = available_tokens(corporation)
            raise GameError, "#{corporation.name} cannot lay this upgrade - no tokens available" if tokens.empty?

            return unless min_token_price(tokens) > buying_power(corporation)

            raise GameError, "#{corporation.name} cannot afford the required token for this upgrade"
          end

          def place_upgrade_token!(corporation, hex)
            city = hex.tile.cities.find do |candidate|
              candidate.tokenable?(corporation, tokens: available_tokens(corporation))
            end
            raise GameError, "#{corporation.name} cannot lay the required token on #{hex.name}" unless city

            place_token(corporation, city, available_tokens(corporation).first)
            @tokened = true
          end

          def corporation_tokened_in_hex?(corporation, hex)
            hex.tile.cities.any? { |city| @game.city_tokened_by?(city, corporation) }
          end

          def different_corporation_tokened_in_hex?(corporation, hex)
            hex.tile.cities.any? { |city| city.tokened? && !@game.city_tokened_by?(city, corporation) }
          end

          def city_empty?(hex)
            hex.tile.cities.any? && hex.tile.cities.none?(&:tokened?)
          end

          def oo_home_token_placed?(hex)
            corporation_id = OO_HOME_CORPORATIONS[hex.id]
            return true unless corporation_id

            @game.corporation_by_id(corporation_id).tokens.first&.used
          end
        end
      end
    end
  end
end
