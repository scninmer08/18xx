# frozen_string_literal: true

require_relative '../../../step/special_track'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialTrack < Engine::Step::SpecialTrack
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
              tile = action.hex.tile
              city = tile.cities.first
              if @game.ic_line_hex?(hex)
                @game.ic_line_improvement(action)
                case tile.color
                when :yellow
                  # checks for one IC Line connection when laying yellow
                  raise GameError, 'Tile must overlay at least one dashed path' if @game.ic_line_connections(hex) < 1

                  @log << "#{action.entity.owner.name} receives a #{@game.format_currency(20)} subsidy from the bank "\
                          '(IC Line improvement)'
                  action.entity.owner.cash += 20
                when :green
                  # checks for both IC Line connections when laying green
                  raise GameError, 'Tile must complete IC Line' if @game.ic_line_connections(hex) < 2

                  # disallows Engineering Master corp from upgrading two incomplete IC Line hexes
                  if @round.num_laid_track > 1 && @round.laid_hexes.first.tile.color == :green &&
                    @game.class::IC_LINE_HEXES.include?(@round.laid_hexes.first)
                    raise GameError, 'Cannot upgrade two incomplete IC Line hexes in one turn'
                  end

                  # adds reservation to IC Line hex when new tile is green city
                  tile.add_reservation!(@game.ic, city) if @game.class::IC_LINE_HEXES.include?(hex.id)

                when :brown
                  tile.remove_reservation!(@game.ic) if @game.class::IC_LINE_HEXES.include?(hex.id)
                end
              end

              # closes GTL if Chicago is upgraded to brown
              if !@game.intro_game? && tile.name == 'CHI3' && !@game.goodrich_transit_line.closed?
                company = @game.goodrich_transit_line
                @log << "#{company.name} (#{company.owner.name}) closes"
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
