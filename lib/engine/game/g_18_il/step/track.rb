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
            hex       = action.hex
            hex_name  = hex.name
            tile_name = action.tile.name # pre-lay (what’s being placed)

            # Block certain upgrades until IC has started
            unless @game.ic.ipoed
              blocked =
                (hex_name == 'H7' && tile_name == 'K31') ||
                (%w[G10 F17 E22].include?(hex_name) && %w[C31 C32].include?(tile_name))
              if blocked
                raise GameError,
                      "Cannot upgrade tile in #{hex.location_name} (#{hex_name}) until Illinois Central has started"
              end
            end

            lay_tile_action(action)

            ic_line_tile(action) if @game.ic_line_hex?(hex)

            # Close GTL if Chicago upgrades to brown
            if !@game.intro_game? && tile_name == 'CHI3' && !@game.goodrich_transit_line.closed?
              company = @game.goodrich_transit_line
              @log << "#{company.name} (#{company.owner.name}) closes"
              company.close!
            end

            pass! unless can_lay_tile?(action.entity)
          end

          def pass_description
            'Pass (Track)'
          end

          # --- override only to tweak one line in the engine's lay_tile ---
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
                remove_border_calculate_cost!(tile, entity_or_entities, spender) # side effect: delete completed borders
                extra_cost
              else
                border, border_types = remove_border_calculate_cost!(tile, entity_or_entities, spender)

                # >>>>> ONLY CHANGE: also add border types even if net border cost is zero
                terrain += border_types if border.positive? || !border_types.empty?
                # <<<<<

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
          # --- end override ---

          def can_lay_tile?(entity)
            return true if tile_lay_abilities_should_block?(entity)
            return true if can_buy_tile_laying_company?(entity, time: type)

            action = get_tile_lay(entity)
            return false unless action

            !entity.tokens.empty? && (buying_power(entity) >= action[:cost]) && (action[:lay] || action[:upgrade])
          end

          def available_hex(entity, hex, normal: false)
            # Highlight the STL hexes only when corp has permit token
            return nil if @game.class::STL_HEXES.include?(hex.id) && !@game.stl_permit?(current_entity)

            # Forces NC to lay in its home hex first if it is not yellow
            if !@game.class::SPRINGFIELD_HEX.include?(hex.id) &&
               @game.hex_by_id(entity.coordinates).tile.color == :white &&
               entity == @game.nc
              return nil
            end

            super
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

          def ic_line_tile(action)
            @game.ic_line_improvement(action)

            hex = action.hex
            tile = hex.tile
            city = tile.cities.first

            case tile.color
            when :yellow
              raise GameError, 'Tile must overlay at least one section of the dashed path' if @game.ic_line_connections(hex) < 1

              @log << "#{action.entity.name} receives a #{@game.format_currency(20)} subsidy from the bank "\
                      '(IC Line improvement)'
              @game.bank.spend(20, action.entity)
            when :green
              raise GameError, 'Tile must complete IC Line' if @game.ic_line_connections(hex) < 2

              if @round.num_laid_track > 1 && @round.laid_hexes.first.tile.color == :green &&
                 @game.class::IC_LINE_CITY_HEXES.include?(@round.laid_hexes.first)
                raise GameError, 'Cannot upgrade two incomplete IC Line hexes in one turn'
              end

              tile.add_reservation!(@game.ic, city) if @game.class::IC_LINE_CITY_HEXES.include?(hex.id) &&
                                                       !@game.ic.tokens.find { |t| t.hex == hex }
            when :brown
              tile.remove_reservation!(@game.ic) if @game.class::IC_LINE_CITY_HEXES.include?(hex.id)
            end
          end
        end
      end
    end
  end
end
