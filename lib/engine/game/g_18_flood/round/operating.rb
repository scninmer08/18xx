# frozen_string_literal: true

require_relative '../../../round/operating'

module Engine
  module Game
    module G18FLOOD
      module Round
        class Operating < Engine::Round::Operating
          attr_accessor :center_touchers

          def setup
            @current_operator = nil
            @home_token_timing = @game.class::HOME_TOKEN_TIMING
            @entities.each { |c| @game.place_home_token(c) } if @home_token_timing == :operating_round
            @entities.each { |e| e.trains.each { |t| t.operated = false } }
            (@game.corporations + @game.minors + @game.companies).each(&:reset_ability_count_this_or!)
            @game.done_this_round.clear

            @center_touchers = {}

            after_setup
          end

          def skip_entity?(entity)
            entity.closed?
          end

          def after_process(action)
            return if action.type == 'message'

            @current_operator_acted = true if action.entity.corporation == @current_operator

            if active_step
              entity  = @entities[@entity_index]
              control = @game.controller(entity)
              return if control&.player? || control&.share_pool?
            end

            after_end_of_turn(@current_operator)
            next_entity! unless @game.finished
          end
        end
      end
    end
  end
end
