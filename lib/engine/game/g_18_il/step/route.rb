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

            actions << 'run_routes'
            return actions if entity == @game.ic && @game.ic_in_receivership?
            return [] if entity.receivership?

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
            @game.rust_rogers! if action.routes.any? { |route| route.train.name == @game.class::ROGERS_NAME }
          ensure
            restore_route_extension!
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

          private

          def restore_route_extension!
            train = @round.route_extension_train
            original = @round.route_extension_original
            return unless train
            return unless original

            train.name = original[:name]
            train.distance = original[:distance]
            @round.route_extension_train = nil
            @round.route_extension_original = nil
          end
        end
      end
    end
  end
end
