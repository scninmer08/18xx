# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class RouteExtension < Engine::Step::Base
          ACTIONS = %w[choose pass].freeze

          def actions(entity)
            return [] unless entity == current_entity
            return [] unless route_extension&.owner == entity
            return [] unless entity.corporation?
            return [] if entity.receivership?
            return [] if entity.trains.empty?

            ACTIONS
          end

          def description
            "Use #{route_extension.name} ability"
          end

          def pass_description
            "Skip (#{route_extension.name})"
          end

          def choice_name
            'Choose a train to extend'
          end

          def choices
            current_entity.trains.to_h { |train| [train.id, extended_train_name(train)] }
          end

          def round_state
            {
              route_extension_train: nil,
              route_extension_original: nil,
            }
          end

          def process_choose(action)
            train = @game.train_by_id(action.choice)
            raise GameError, 'Route Extension train must be owned by the corporation' unless train&.owner == action.entity

            @round.route_extension_train = train
            @round.route_extension_original = { name: train.name, distance: train.distance }
            extend_train!(train)
            @log << "#{action.entity.name} uses #{route_extension.name} to extend its " \
                    "#{@round.route_extension_original[:name]} train to #{train.name}"
            pass!
          end

          def log_pass(entity)
            @log << "#{entity.name} declines to use #{route_extension.name}"
          end

          def log_skip(_entity); end

          private

          def route_extension
            @game.company_by_id('RE')
          end

          def extended_train_name(train)
            "#{train.name} → #{extended_name(train.name)}"
          end

          def extend_train!(train)
            return if train.name == 'D'

            train.name = extended_name(train.name)
            train.distance = train.distance.map do |distance|
              next distance unless (distance['nodes'] & %w[city offboard]).any?

              distance.merge(
                'nodes' => (distance['nodes'] | %w[city offboard]),
                'pay' => distance['pay'] + 1,
                'visit' => distance['visit'] + 1,
              )
            end
          end

          def extended_name(name)
            if (match = name.match(/\A(\d+)\z/))
              (match[1].to_i + 1).to_s
            elsif (match = name.match(/\A(\d+)(\+\d+C)\z/))
              "#{match[1].to_i + 1}#{match[2]}"
            else
              name
            end
          end
        end
      end
    end
  end
end
