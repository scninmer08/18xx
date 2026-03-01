# frozen_string_literal: true

require_relative '../../g_18_il/step/conversion'

module Engine
  module Game
    module G18IlSolo
      module Step
        class Conversion < G18IL::Step::Conversion
          def actions(entity)
            return [] if entity.owner == @game.ic || entity.owner == @game.robot

            super
          end

          def log_skip(entity)
            return if entity.owner == @game.ic || entity.owner == @game.robot

            super
          end
        end
      end
    end
  end
end
