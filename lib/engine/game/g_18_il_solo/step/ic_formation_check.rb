# frozen_string_literal: true

require_relative '../../g_18_il/step/ic_formation_check'

module Engine
  module Game
    module G18IlSolo
      module Step
        class IcFormationCheck < G18IL::Step::IcFormationCheck
          def skip!
            @game.auto_ic_line_lay! if (@round.entity_index == @round.entities.size - 1) && !@game.ic_line_completed?

            super
          end
        end
      end
    end
  end
end
