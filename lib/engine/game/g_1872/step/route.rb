# frozen_string_literal: true

require_relative '../../../step/route'

module Engine
  module Game
    module G1872
      module Step
        class Route < Engine::Step::Route
          def actions(entity)
            return [] if entity&.corporation? && @game.isolated_shell?(entity)

            super
          end

          def process_run_routes(action)
            first_route = !action.entity.operated? && action.routes.any?

            super

            return unless first_route

            action.entity.mark_operated!
            @game.pay_land_grant_subsidy_for_first_route!(action.entity)
          end
        end
      end
    end
  end
end
