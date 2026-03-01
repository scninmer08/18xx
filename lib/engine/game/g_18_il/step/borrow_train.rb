# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class BorrowTrain < Engine::Step::Base
          ACTIONS = %w[borrow_train].freeze
          def actions(entity)
            return [] unless entity.corporation?
            return [] unless can_borrow_train?(entity)

            ACTIONS
          end

          def description
            'Borrow Train'
          end

          def blocks?
            can_borrow_train?(current_entity)
          end

          def can_borrow_train?(entity)
            !borrowable_trains(entity).empty? && entity.trains.empty?
          end

          def borrowable_trains(entity)
            abilites = @game.abilities(entity, :borrow_train)
            return [] unless abilites

            trains = Array(abilites).flat_map do |a|
              a.train_types.map { |typ| @game.depot.depot_trains.find { |t| t.sym == typ } }.compact
            end.uniq

            trains.reject! { |t| t.name == 'D' } if trains.any? { |t| t.name == '6' }

            trains
          end

          def process_borrow_train(action)
            @game.borrow_train(action)
            pass!
          end
        end
      end
    end
  end
end
