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

          def finished?
            return false unless super

            unless @train_export_triggered
              @game.export_train
              @train_export_triggered = true
            end

            super
          end
        end
      end
    end
  end
end
