# frozen_string_literal: true

require_relative '../../../step/route'

module Engine
  module Game
    module G18IL
      module Step
        class Route < Engine::Step::Route
          def actions(entity)
            return [] if !entity.operator? || @game.route_trains(entity).empty? || !@game.can_run_route?(entity)

            actions = []
            return actions unless entity.corporation?
            return [] if entity.receivership?

            actions << 'run_routes'
            return actions if entity == @game.ic && @game.ic_in_receivership?

            actions << 'scrap_train' if scrappable_trains(entity).count > 1 && !@game.last_set
            actions
          end

          def scrappable_trains(entity)
            entity.trains
          end

          def scrap_info(_train)
            ''
          end

          def process_run_routes(action)
            super
            @game.pay_fwc_bonus!(@round.routes, action.entity) unless @game.intro_game?
          end

          def scrap_button_text(_train)
            'Scrap'
          end

          def help
            return super if current_entity != @game.ic || !@game.ic_in_receivership?

            "#{current_entity.name} is in receivership (it has no president). Most of its "\
              'actions are automated, but it must have a player run its trains. '\
              "Please enter the best route you see for #{current_entity.name}."
          end

          def process_scrap_train(action)
            raise GameError, 'Can only scrap trains owned by the corporation' if action.entity != action.train.owner

            @game.scrap_train(action.train)
          end
        end
      end
    end
  end
end
