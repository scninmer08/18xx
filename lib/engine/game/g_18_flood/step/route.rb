# frozen_string_literal: true

require_relative '../../../step/route'

module Engine
  module Game
    module G18FLOOD
      module Step
        class Route < Engine::Step::Route
          def log_skip(entity)
            return if @game.shell_first_or?(entity)

            super
          end

          def process_run_routes(action)
            super
            @game.center_used = true if action.routes.any? { |r| r.stops.any? { |s| s.hex&.id == @game.center_hex_id } }
          end
        end
      end
    end
  end
end
