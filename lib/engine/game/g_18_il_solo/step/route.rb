# frozen_string_literal: true

require_relative '../../g_18_il/step/route'

module Engine
  module Game
    module G18IlSolo
      module Step
        class Route < G18IL::Step::Route
          def actions(entity)
            return [] if !entity.operator? || @game.route_trains(entity).empty? || !@game.can_run_route?(entity)

            actions = []
            return actions unless entity.corporation?
            return [] if entity.receivership?

            actions << 'run_routes'
            return actions if entity == @game.ic && @game.ic_in_receivership?

            actions << 'scrap_train' if scrappable_trains(entity).count > 1 && !@game.last_set && entity.owner != @game.robot
            actions
          end
        end
      end
    end
  end
end
