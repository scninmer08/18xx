# frozen_string_literal: true

require_relative '../../../round/operating'

module Engine
  module Game
    module G1872
      module Round
        class Operating < Engine::Round::Operating
          def after_process(action)
            return if action.type == 'message'

            @current_operator_acted = true if action.entity.corporation == @current_operator

            if active_step
              controller = @game.acting_for_entity(@entities[@entity_index])
              return if controller&.player? || controller&.share_pool?
            end

            after_end_of_turn(@current_operator)
            next_entity! unless @game.finished
          end
        end
      end
    end
  end
end
