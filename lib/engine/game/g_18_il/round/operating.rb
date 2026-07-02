# frozen_string_literal: true

require_relative '../../../round/operating'

module Engine
  module Game
    module G18IL
      module Round
        class Operating < Engine::Round::Operating
          def setup
            super
            @train_export_triggered = false
          end

          def next_entity!
            clear_cache!
            return if @entities.empty?

            super
          end

          def start_operating
            entity = @entities[@entity_index]
            return next_entity! if skip_entity?(entity)

            @current_operator = entity
            @current_operator_acted = false
            actor_name = @game.acting_for_entity(entity)&.name || entity.name
            @log << "#{actor_name} operates #{entity.name}" unless finished?
            @game.place_home_token(entity) if @home_token_timing == :operate
            skip_steps
            return unless finished?

            after_end_of_turn(entity)
            next_entity!
          end

          def finished?
            return false unless super

            unless @train_export_triggered
              @game.export_train
              @train_export_triggered = true
              clear_cache!
            end

            !@game.pending_rusting_event
          end
        end
      end
    end
  end
end
