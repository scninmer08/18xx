# frozen_string_literal: true

require_relative '../../g_18_il/step/issue_shares'

module Engine
  module Game
    module G18IlSolo
      module Step
        class IssueShares < G18IL::Step::IssueShares
          def actions(entity)
            return [] if entity.owner == @game.robot

            super
          end

          def log_skip(entity)
            return if entity.owner == @game.robot

            super
          end
        end
      end
    end
  end
end
