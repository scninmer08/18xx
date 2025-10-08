# frozen_string_literal: true

require_relative '../../../step/track'

module Engine
  module Game
    module G18FLOOD
      module Step
        class Track < Engine::Step::Track
          def actions(entity)
            return [] unless @game.national_corporation?(entity)
            return [] if @game.lumber[entity].zero?

            super
          end

          def log_skip(entity)
            return if @game.shell_corporation?(entity)

            super
          end

          def available_hex(entity_or_entities, hex)
            return nil if @game.center_hex?(hex) && hex.tile&.color != :white

            super
          end

          # ---------------- Resource usage ----------------

          def tile_resource_usage_for(color)
            case color
            when :yellow then { lumber: 1, steel: 0 }
            when :green  then { lumber: 1, steel: 1 }
            when :brown  then { lumber: 1, steel: 2 }
            when :gray   then { lumber: 1, steel: 3 }
            when :purple then { lumber: 1, steel: 4 }
            else              { lumber: 0, steel: 0 }
            end
          end

          def spend_resources(entity, tile)
            used = tile_resource_usage_for(tile.color)
            raise GameError, 'Not enough lumber' if used[:lumber].positive? && @game.lumber[entity] < used[:lumber]
            raise GameError, 'Not enough steel'  if used[:steel].positive?  && @game.steel[entity]  < used[:steel]

            @game.lumber[entity] -= used[:lumber]
            @game.steel[entity]  -= used[:steel]
            @last_tile_usage = used
          end

          # ---------------- Split terrain logic ----------------

          def base_terrain_cost_for(hex)
            orig = hex.original_tile
            return 0 unless orig

            raw = orig.upgrades.sum { |u| Integer(u.cost || 0) }
            return 0 if raw.zero?

            # Preprinted city adjustments (your “hidden” base costs)
            if orig.preprinted && orig.cities.any?
              case orig.color
              when :yellow then ((raw * 3.0) / 2).round
              when :green  then raw * 3
              else raw
              end
            else
              raw
            end
          end

          def upgrade_possible_from_tile_to_color?(from_tile, to_color, chooser)
            sel = chooser || current_entity
            sel = sel.owner if sel&.company?
            candidates = @game.tiles.select { |t| t.color == to_color }
            candidates.any? { |t| @game.upgrades_to?(from_tile, t, false, selected_company: sel) }
          end

          # ----- Generalized future-cost policy (simple + strict) -----
          FUTURE_COST = {
            yellow: { next: :green, fraction: 2.0 / 3.0 },
            green: { next: :brown,  fraction: 1.0 / 3.0  },
            brown: { next: :gray,   fraction: 1.0 / 6.0  },
            gray: { next: :purple, fraction: 1.0 / 12.0 },
            purple: { next: nil,     fraction: 0.0 },
          }.freeze

          def compute_future_cost(placed_tile, hex, chooser)
            base = base_terrain_cost_for(hex)
            return 0 if base.zero?

            rule = FUTURE_COST[placed_tile.color] || {}
            nxt  = rule[:next]
            frac = rule[:fraction] || 0.0
            return 0 if nxt.nil? || frac.zero?

            # Only stamp if the next color is actually reachable from this tile.
            return 0 unless upgrade_possible_from_tile_to_color?(placed_tile, nxt, chooser)

            (base * frac).round
          end

          def set_future_cost_on!(tile, amount)
            tile.upgrades = amount.positive? ? [Part::Upgrade.new(amount, [:mountain], nil)] : []
          end

          def upgradeable_tiles(entity_or_entities, ui_hex)
            hex = @game.hex_by_id(ui_hex.id) # UI hex can go stale
            tiles = super                    # lets the engine compute legal rotations

            chooser = Array(entity_or_entities).first

            tiles.map do |t|
              # Work on a preview copy but PRESERVE rotation + legal rotations
              copy = t.dup
              copy.legal_rotations = t.legal_rotations.dup
              copy.rotate!(t.rotation)

              # Apply generalized future-cost rule to the preview
              future = compute_future_cost(copy, hex, chooser)
              set_future_cost_on!(copy, future)
              copy
            end
          end

          def lay_tile(action, extra_cost: 0, entity: nil, spender: nil)
            new_tile = action.tile
            hex      = action.hex

            # Ensure we lay a real pool tile (UI previews/clones have no hex)
            if new_tile.hex || !@game.tiles.include?(new_tile)
              replacement = @game.tiles.find { |t| t.name == new_tile.name && t.color == new_tile.color && !t.hex }
              raise GameError, "No available pool tile #{new_tile.name}" unless replacement

              action.instance_variable_set(:@tile, replacement)
              new_tile = replacement
            end

            # Capture the current tile (cost is computed from this one inside super)
            old = hex.tile

            # Spend resources first
            spend_resources(action.entity, new_tile)

            # Let the engine validate, compute cost (using old), pay, and lay
            super(action, extra_cost: extra_cost, entity: entity, spender: spender)

            # Now that cost has been charged, scrub any stamped future-costs from the tile we just replaced
            # so the returned pool copy is clean.
            old.upgrades = [] if old && %i[yellow green brown gray].include?(old.color) && !old.preprinted

            # Stamp the *future* cost on the newly placed tile (for its next upgrade)
            placed  = hex.tile
            chooser = entity || current_entity
            future  = compute_future_cost(placed, hex, chooser)
            set_future_cost_on!(placed, future)
          end

          # --------------- Logging (money + resources) -----------------

          def oxford_join(parts)
            case parts.size
            when 0 then ''
            when 1 then parts.first
            when 2 then "#{parts[0]} and #{parts[1]}"
            else        "#{parts[0..-2].join(', ')}, and #{parts[-1]}"
            end
          end

          def pay_tile_cost!(entity_or_entities, tile, rotation, hex, spender, cost, _extra_cost)
            entities = Array(entity_or_entities)
            entity, *_combo_entities = entities

            try_take_loan(spender, cost) if respond_to?(:try_take_loan, true)
            spender.spend(cost, @game.bank) if cost.positive?

            used = @last_tile_usage || { lumber: 0, steel: 0 }
            @last_tile_usage = nil

            parts = []
            parts << @game.format_currency(cost) if cost.positive?
            parts << "#{used[:lumber]} lumber" if used[:lumber].positive?
            parts << "#{used[:steel]} steel"    if used[:steel].positive?
            spends_phrase = parts.empty? ? '' : " spends #{oxford_join(parts)} and"

            @log << "#{spender.name}"\
                    "#{spender == entity || !entity.company? ? '' : " (#{entities.map(&:sym).join('+')})"}"\
                    "#{spends_phrase} lays tile ##{tile.name}"\
                    " with rotation #{rotation} on #{hex.name}"\
                    "#{tile.location_name.to_s.empty? ? '' : " (#{tile.location_name})"}"
          end
        end
      end
    end
  end
end
