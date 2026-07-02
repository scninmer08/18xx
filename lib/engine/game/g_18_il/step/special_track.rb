# frozen_string_literal: true

require_relative '../../../step/special_track'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialTrack < Engine::Step::SpecialTrack
          def actions(entity)
            return [] if entity == @game.company_by_id('CIB') && !@game.phase.tiles.include?(:gray)

            super
          end

          def tile_lay_available?(company)
            return false if actions(company).empty?

            @game.hexes.any? do |hex|
              available_hex(company, hex) && potential_tiles(company, hex).any?
            end
          end

          def potential_tiles(entity_or_entities, hex)
            entities = Array(entity_or_entities)
            entity = entities.first
            return [] unless (tile_ability = abilities(entity))

            tiles = tile_ability.tiles.map do |name|
              @game.tiles.find { |t| t.name == name } || @game.find_private_ability_tile(name)
            end
            tiles = @game.tiles.uniq(&:name) if tile_ability.tiles.empty?

            special = tile_ability.special if tile_ability.type == :tile_lay
            tiles
              .compact
              .select do |t|
                @game.tile_valid_for_phase?(t, hex: hex, phase_color_cache: potential_tile_colors(entity, hex)) &&
                  @game.upgrades_to?(hex.tile, t, special, selected_company: entity)
              end
          end

          def process_lay_tile(action)
            if @company && (@company != action.entity) &&
               (ability = @game.abilities(@company, :tile_lay, time: 'track')) &&
               ability.must_lay_together && ability.must_lay_all
              raise GameError, "Cannot interrupt #{@company.name}'s tile lays"
            end

            ability = abilities(action.entity)
            owner = if !action.entity.owner
                      nil
                    elsif action.entity.owner.corporation?
                      action.entity.owner
                    else
                      @game.current_entity
                    end
            if ability.type == :teleport ||
               (ability.type == :tile_lay && ability.consume_tile_lay)
              lay_tile_action(action, spender: owner)

            else
              lay_tile(action, spender: owner)

              hex = action.hex
              @game.process_ic_line(action, beneficiary: action.entity.owner, round: @round) if @game.ic_line_hex?(hex)

              # Flip GTL if Chicago upgrades to brown, including while GTL is unowned.
              @game.flip_private!(@game.company_by_id('GTL')) if !@game.intro_game? && action.tile.name == 'CHI3'

              ability.laid_hexes << action.hex.id
              @round.laid_hexes << action.hex
              check_connect(action, ability)
            end
            ability.use!(upgrade: %i[green brown gray].include?(action.tile.color))

            # Record any track laid after the dividend step.
            if owner&.corporation? && (operating_info = owner.operating_history[[@game.turn, @round.round_num]])
              operating_info.laid_hexes = @round.laid_hexes
            end

            if ability.type == :tile_lay
              @game.flip_private!(ability.owner) if ability.count&.zero?
              @company = ability.count.positive? ? action.entity : nil if ability.must_lay_together
            end

            return unless ability.type == :teleport

            company = ability.owner
            tokener = company.owner
            tokener = @game.current_entity if tokener.player?
            if tokener.tokens_by_type.empty?
              company.remove_ability(ability)
            else
              @round.teleported = company
              @round.teleport_markerer = tokener
            end
          end
        end
      end
    end
  end
end
