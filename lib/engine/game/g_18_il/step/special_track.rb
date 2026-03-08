# frozen_string_literal: true

require_relative '../../../step/special_track'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialTrack < Engine::Step::SpecialTrack
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

              # closes GTL if Chicago is upgraded to brown
              if !@game.intro_game? && tile.name == 'CHI3' && !@game.company_by_id('GTL').closed?
                company = @game.company_by_id('GTL')
                owner_str = company.owner ? " (#{company.owner.name})" : ''
                @log << "#{company.name}#{owner_str} closes"
                company.close!
              end

              ability.laid_hexes << action.hex.id
              @round.laid_hexes << action.hex
              check_connect(action, ability)
            end
            ability.use!(upgrade: %i[green brown gray].include?(action.tile.color))

            # Record any track laid after the dividend step
            if owner&.corporation? && (operating_info = owner.operating_history[[@game.turn, @round.round_num]])
              operating_info.laid_hexes = @round.laid_hexes
            end

            if ability.type == :tile_lay
              if ability.count&.zero? && ability.closed_when_used_up
                company = ability.owner
                @game.company_closing_after_using_ability(company)
                company.close!
              end
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
