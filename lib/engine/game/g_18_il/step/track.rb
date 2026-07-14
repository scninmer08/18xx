# frozen_string_literal: true

require_relative '../../../step/track'

module Engine
  module Game
    module G18IL
      module Step
        class Track < Engine::Step::Track
          ACTIONS = %w[lay_tile pass].freeze

          def actions(entity)
            return [] if @game.last_set
            return [] unless entity == current_entity
            return [] if entity.company? || !can_lay_tile?(entity)
            return [] if entity == @game.ic && @game.ic_in_receivership?

            ACTIONS
          end

          def process_lay_tile(action)
            if (special_track = @round.steps.find { |step| step.is_a?(G18IL::Step::SpecialTrack) }) &&
               (company = special_tile_lay_company(action, special_track))
              special_action = Engine::Action::LayTile.new(
                company,
                tile: action.tile,
                hex: action.hex,
                rotation: action.rotation,
                combo_entities: action.combo_entities
              )
              special_track.process_lay_tile(special_action)

              pass! unless can_lay_tile?(action.entity)
              return
            end

            hex       = action.hex
            tile_name = action.tile.name

            lay_tile_action(action)

            @game.process_ic_line(action, beneficiary: action.entity, round: @round) if @game.ic_line_hex?(hex)

            @game.remove_gtl_chicago_reservation! if !@game.intro_game? && tile_name == 'CHI3'

            pass! unless can_lay_tile?(action.entity)
          end

          def pass_description
            'Pass (Track)'
          end

          def special_tile_lay_company(action, special_track)
            return unless action.entity.corporation?

            @game.companies.find do |company|
              next unless company.owner == action.entity
              next unless %w[CIB CVCC FWC].include?(company.sym)
              next if special_track.actions(company).empty?
              next unless special_track.available_hex(company, action.hex)

              special_track.potential_tiles(company, action.hex).any? { |tile| tile.name == action.tile.name }
            end
          end

          def hex_neighbors(entity, hex)
            neighbors = super || long_walk_hex_neighbors(entity, hex)
            stl_construction_neighbors(entity, hex, neighbors)
          end

          def stl_construction_neighbors(entity, hex, neighbors)
            return neighbors unless entity.corporation?
            return neighbors unless neighbors
            return neighbors if stl_station_token?(entity)

            stl_hexes = @game.class::STL_HEXES

            filtered = neighbors.reject do |edge|
              neighbor = hex.neighbors[edge]
              stl_hexes.include?(hex.id) || (neighbor && stl_hexes.include?(neighbor.id))
            end
            filtered.empty? ? nil : filtered
          end

          def stl_station_token?(entity)
            @game.class::STL_TOKEN_HEX.any? do |hex_id|
              @game.hex_by_id(hex_id).tile.cities.any? { |city| @game.city_tokened_by?(city, entity) }
            end
          end

          def long_walk_hex_neighbors(entity, hex)
            return unless entity.corporation?

            long_walk_connected_hexes(entity)[hex]
          end

          def long_walk_connected_hexes(entity)
            skip_paths = @game.graph_skip_paths(entity)
            hexes = Hash.new { |h, k| h[k] = [] }
            visited_nodes = {}
            visited_paths = {}
            queue = []

            @game.hexes.each do |hex|
              hex.tile.cities.each do |city|
                next if !@game.city_tokened_by?(city, entity) &&
                        !@game.for_graph_city_tokened_by?(city, entity, @game.graph_for_entity(entity))

                hex.neighbors.each_key { |edge| hexes[hex] << edge }
                queue << [:node, city]
              end
            end

            until queue.empty?
              type, part = queue.shift
              next unless part

              if type == :node
                next if visited_nodes[part]

                visited_nodes[part] = true
                part.paths.each do |path|
                  next if path.ignore?
                  next if skip_paths&.key?(path)

                  queue << [:path, path]
                end
              else
                next if visited_paths[part]
                next if skip_paths&.key?(part)

                visited_paths[part] = true

                part.exits.each do |edge|
                  hex = part.hex
                  hexes[hex] << edge
                  hexes[hex.neighbors[edge]] << hex.invert(edge) if hex.neighbors[edge]
                end

                part.junction&.paths&.each { |path| queue << [:path, path] unless visited_paths[path] }

                part.edges.each do |edge_part|
                  edge = edge_part.num
                  next unless (neighbor = part.hex.neighbors[edge])

                  neighbor_edge = part.hex.invert(edge)
                  neighbor.paths[neighbor_edge].each do |neighbor_path|
                    next if visited_paths[neighbor_path]
                    next unless part.lane_match?(part.exit_lanes[edge], neighbor_path.exit_lanes[neighbor_edge])
                    next if !part.ignore_gauge_walk && !part.tracks_match?(neighbor_path, dual_ok: true)

                    queue << [:path, neighbor_path]
                  end
                end

                next if part.terminal?

                part.nodes.each do |node|
                  next if visited_nodes[node]
                  next if node.blocks?(entity)

                  queue << [:node, node]
                end
              end
            end

            hexes.transform_values(&:uniq)
          end

          # Override lay_tile to include border types in terrain even when net border cost is zero.
          # The parent only does `terrain += border_types if border.positive?`, but 18IL needs
          # border types recorded even for zero-cost borders (e.g. rivers without a terrain cost).
          def lay_tile(action, extra_cost: 0, entity: nil, spender: nil)
            entity ||= action.entity
            entities = [entity, *action.combo_entities]
            entity_or_entities = action.combo_entities.empty? ? entity : entities

            spender ||= entity
            tile = action.tile
            hex = action.hex
            rotation = action.rotation
            old_tile = hex.tile
            graph = @game.graph_for_entity(spender)

            if !@game.loading && (blocking_ability = ability_blocking_hex(entity, hex))
              raise GameError, "#{hex.id} is blocked by #{blocking_ability.owner.name}"
            end

            tile.rotate!(rotation)

            unless @game.upgrades_to?(old_tile, tile, entity.company?, selected_company: (entity.company? && entity) || nil)
              raise GameError, "#{old_tile.name} is not upgradeable to #{tile.name}"
            end
            if !@game.loading && !legal_tile_rotation?(entity_or_entities, hex, tile)
              raise GameError, "#{old_tile.name} is not legally rotated for #{tile.name}"
            end

            update_tile_lists(tile, old_tile)
            hex.lay(tile)

            if @game.class::IMPASSABLE_HEX_COLORS.include?(old_tile.color)
              hex.all_neighbors.each do |direction, neighbor|
                next if hex.tile.borders.any? { |border| border.edge == direction && border.type == :impassable }
                next unless tile.exits.include?(direction)

                neighbor.neighbors[neighbor.neighbor_direction(hex)] = hex
                hex.neighbors[direction] = neighbor
              end
            end

            @game.clear_graph_for_entity(entity)
            free = false
            discount = 0
            teleport = false
            ability_found = false
            discount_abilities = []

            entities.each do |entity_|
              abilities(entity_) do |ability|
                next if ability.owner != entity_
                next if !ability.hexes.empty? && !ability.hexes.include?(hex.id)
                next if !ability.tiles.empty? && !ability.tiles.include?(tile.name)

                ability_found = true
                if ability.type == :teleport
                  teleport ||= true
                  free = true if ability.free_tile_lay
                  if ability.cost&.positive?
                    spender.spend(ability.cost, @game.bank)
                    @log << "#{spender.name} (#{ability.owner.sym}) spends #{@game.format_currency(ability.cost)} "\
                            "and teleports to #{hex.name} (#{hex.location_name})"
                  end
                else
                  raise GameError, "Track laid must be connected to one of #{spender.id}'s tokens" if ability.reachable &&
                    hex.name != spender.coordinates &&
                    !@game.loading &&
                    !graph.reachable_hexes(spender)[hex]

                  free ||= ability.free
                  discount += ability.discount
                  discount_abilities << ability if discount&.positive?
                  extra_cost += ability.cost
                end
              end
            end

            if entity.company? && !ability_found
              raise GameError, "#{entity.name} does not have an ability that allows them to lay this tile"
            end

            check_track_restrictions!(entity, old_tile, tile) unless teleport

            terrain = old_tile.terrain
            cost =
              if free
                remove_border_calculate_cost!(tile, entity_or_entities, spender)
                extra_cost
              else
                border, border_types = remove_border_calculate_cost!(tile, entity_or_entities, spender)
                terrain += border_types if border.positive? || !border_types.empty?

                base_cost = @game.upgrade_cost(old_tile, hex, entity, spender) + border + extra_cost

                unless discount_abilities.empty?
                  discount = [base_cost, discount].min
                  @game.log_cost_discount(spender, discount_abilities, discount)
                end

                @game.tile_cost_with_discount(tile, hex, entity, spender, base_cost - discount)
              end

            pay_tile_cost!(entity_or_entities, tile, rotation, hex, spender, cost, extra_cost)
            update_token!(action, entity, tile, old_tile)

            @game.all_companies_with_ability(:tile_income) do |company, ability|
              if !ability.terrain
                pay_all_tile_income(company, ability)
              else
                pay_terrain_tile_income(company, ability, terrain, entity, spender)
              end
            end
          end

          def can_lay_tile?(entity)
            return true if tile_lay_abilities_should_block?(entity)
            return true if can_buy_tile_laying_company?(entity, time: type)

            action = get_tile_lay(entity)
            return false unless action

            !entity.tokens.empty? && (buying_power(entity) >= action[:cost]) && (action[:lay] || action[:upgrade])
          end

          def tile_lay_abilities_should_block?(entity)
            abilities = [type, 'owning_player_track'].flat_map do |time|
              Array(abilities(entity, time: time, passive_ok: false))
            end
            special_track = @round.steps.find { |step| step.is_a?(G18IL::Step::SpecialTrack) }
            abilities.reject! do |ability|
              company = ability.owner
              %w[CIB CVCC FWC].include?(company&.sym) && !special_track&.tile_lay_available?(company)
            end

            abilities.any? { |ability| !ability.consume_tile_lay }
          end

          def available_hex(entity, hex, normal: false)
            # An STL permit allows routes to visit St. Louis, but it is not a station
            # token and cannot anchor track construction in the STL area.
            return nil if @game.class::STL_HEXES.include?(hex.id) && !stl_station_token?(entity)

            # Force NC to lay in its home hex first if it is not yellow.
            home_hex = @game.hex_by_id(entity.coordinates)
            if !@game.class::SPRINGFIELD_HEX.include?(hex.id) &&
               home_hex&.tile&.color == :white &&
               entity == @game.corporation_by_id('NC')
              return nil
            end

            super(entity, hex)
          end

          def pay_terrain_tile_income(company, ability, terrain, entity, spender)
            return unless terrain.include?(ability.terrain)
            return if ability.owner_only && company.owner != entity && company.owner != spender

            count  = terrain.count { |t| t == ability.terrain }
            income = ability.income * count
            @game.bank.spend(income, company.owner)

            noun = if ability.terrain.to_sym == :water
                     count > 1 ? 'bridges' : 'bridge'
                   else
                     count > 1 ? "#{ability.terrain} tiles" : "#{ability.terrain} tile"
                   end

            @log << "#{company.owner.name} earns #{@game.format_currency(income)} for the #{noun} built by #{company.name}"
          end
        end
      end
    end
  end
end
