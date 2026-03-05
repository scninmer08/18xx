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
            super
          end

          def finished?
            return false unless super

            unless @train_export_triggered
              @game.export_train
              @train_export_triggered = true
            end

            true
          end
        end
      end
    end
  end
end
