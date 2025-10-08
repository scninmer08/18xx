# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18FLOOD
      module Step
        class ShellChoice < Engine::Step::Base
          ACTIONS = %w[choose].freeze

          def setup
            @finished = false
            super
          end

          def actions(entity)
            return [] unless entity == current_entity
            return [] unless @game.national_corporation?(entity)
            return [] unless entity.tokens.count(&:used) > 1
            return [] if @finished
            return [] if entity.cash < 5 * @game.stock_market.par_prices.min_by(&:price).price
            return [] unless @game.shell_parent.count { |_sh, parent| parent == entity } < 3

            ACTIONS
          end

          def description
            'Create a Shell Company'
          end

          def active?
            !active_entities.empty?
          end

          def active_entities
            return [] if @finished

            [@round.current_operator]
          end

          def choices
            {
              'create' => 'Create',
              'pass' => 'Pass',
            }
          end

          def choice_available?(entity)
            entity == current_entity && !@finished
          end

          def choice_name
            'Create a Shell Company'
          end

          def log_skip(entity)
            return if @game.shell_corporation?(entity)

            super
          end

          def process_choose(action)
            if action.choice == 'pass'
              process_pass(action)
            else
              @game.create_shell_company(action.entity)
            end
            @finished = true
          end
        end
      end
    end
  end
end
