# frozen_string_literal: true

require_relative '../../../step/track_and_token'

module Engine
  module Game
    module G1872
      module Step
        class TrackAndToken < Engine::Step::TrackAndToken
          OO_HOME_CORPORATIONS = {
            'B38' => 'CNW',
            'H42' => 'KP',
          }.freeze

          def potential_tiles(entity_or_entities, hex)
            tiles = super
            corporation = track_corporation(entity_or_entities)

            tiles = tiles.reject { |tile| tile.name == 'X00' && hex.id != 'B4' }

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
            raise GameError, 'Tile #X00 may only be laid in Cheyenne or by using Big Creek Land Company' if
              action.tile.name == 'X00' && action.hex.id != 'B4'

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
            @game.mines_connection_changed!
            @game.remove_connected_unauctioned_land_grants!

            place_upgrade_token!(corporation, action.hex) if needs_upgrade_token
            @game.assimilate_connected_branches!

            return unless palmer_greenwood

            @game.company_closing_after_using_ability(palmer_greenwood)
            palmer_greenwood.close!
          end

          def process_place_token(action)
            reserved_company = private_reservation_company(action.entity, action.city)
            super
            close_private_reservation_company!(reserved_company) if reserved_company
            @game.assimilate_connected_branches!
          end

          def process_remove_token(action)
            token = token_at_slot(action.city, action.slot)
            raise GameError, 'That station is not abandoned' unless can_replace_token?(action.entity, token)

            cost = @game.class::ABANDONED_STATION_REMOVAL_COST
            action.entity.spend(cost, @game.bank)
            @log << "#{action.entity.name} removes #{token.corporation.name}'s abandoned station from "\
                    "#{action.city.hex.name} for #{@game.format_currency(cost)}"
            @game.remove_abandoned_station!(token)
            @game.graph.clear_graph_for_all
            @game.assimilate_connected_branches!
          end

          def can_replace_token?(entity, token)
            abandoned_station_removal_available?(entity) && @game.abandoned_station?(token)
          end

          def legal_tile_rotation?(entity_or_entities, hex, tile)
            return super unless town_upgrade?(hex.tile, tile)

            entity = track_corporation(entity_or_entities)
            old_exits = hex.tile.exits
            new_exits = tile.exits
            (old_exits - new_exits).empty? &&
              new_exits.size == old_exits.size + 1 &&
              tile.towns.one? &&
              new_exits.all? { |edge| hex.neighbors[edge] } &&
              !(new_exits & Array(hex_neighbors(entity, hex))).empty?
          end

          def check_track_restrictions!(entity, old_tile, new_tile)
            return if old_tile.name == '9' && %w[141 142].include?(new_tile.name)
            return if green_city_slot_upgrade?(old_tile, new_tile)

            super
          end

          def can_lay_tile?(entity)
            return false if isolated_branch?(entity) && @round.num_laid_track.positive?
            return false if branch?(entity) && !isolated_branch?(entity)

            super
          end

          def process_lay_tile(action)
            super
            pass! if isolated_branch?(action.entity)
          end

          def available_hex(entity, hex)
            return false unless entity == current_entity
            return true if abandoned_station_removal_available?(entity) && abandoned_station_in_hex?(hex)
            return true if can_lay_tile?(entity) && tracker_available_hex(entity, hex)
            return false if isolated_branch?(entity)
            return false unless oo_home_token_placed?(hex)
            return true if can_place_token?(entity) && tokener_available_hex(entity, hex)

            false
          end

          def actions(entity)
            unless isolated_branch?(entity)
              actions = super
              if abandoned_station_removal_available?(entity)
                pass_index = actions.index('pass')
                pass_index ? actions.insert(pass_index, 'remove_token') : actions.concat(%w[remove_token pass])
              end
              return actions
            end

            return [] unless entity == current_entity
            return [] unless can_lay_tile?(entity)

            %w[lay_tile pass]
          end

          private

          def abandoned_station_removal_available?(entity)
              entity&.corporation? &&
              entity == current_entity &&
              buying_power(entity) >= @game.class::ABANDONED_STATION_REMOVAL_COST &&
              @game.abandoned_stations.any?
          end

          def abandoned_station_in_hex?(hex)
            hex.tile.cities.any? do |city|
              (city.tokens + city.extra_tokens).compact.any? { |token| @game.abandoned_station?(token) }
            end
          end

          def token_at_slot(city, slot)
            normal_slots = city.tokens.size
            return city.tokens[slot] if slot < normal_slots

            city.extra_tokens[slot - normal_slots]
          end

          def palmer_greenwood_available?(corporation)
            palmer_greenwood = @game.company_by_id('PGS')
            palmer_greenwood && !palmer_greenwood.closed? && palmer_greenwood.owner == corporation
          end

          def isolated_branch?(corporation)
            corporation&.corporation? && @game.isolated_branch?(corporation)
          end

          def branch?(corporation)
            corporation&.corporation? && corporation.type == :branch
          end

          def private_reservation_company(entity, city)
            @game.companies.find do |company|
              company.owner == entity &&
                !company.closed? &&
                Array(@game.abilities(company, :reservation)).any? do |ability|
                  ability.hex == city.hex.id && ability.city == city.index && city.reserved_by?(entity)
                end
            end
          end

          def close_private_reservation_company!(company)
            ability = Array(@game.abilities(company, :reservation)).first
            city = @game.hex_by_id(ability.hex).tile.cities[ability.city]
            city.remove_reservation!(company)
            @game.company_closing_after_using_ability(company)
            company.close!
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
            return false if branch?(corporation)
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

          def validate_upgrade_token!(corporation, _hex)
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
