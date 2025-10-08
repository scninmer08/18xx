# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18FLOOD
      module Step
        class ParShell < Engine::Step::Base
          ACTIONS = %w[choose].freeze
          PARS = [60, 80, 100, 120].freeze

          def setup
            @finished = false
            super
          end

          def actions(entity)
            return [] unless entity == current_entity
            return [] if @finished
            return [] unless pending_shell_for?(entity)

            ACTIONS
          end

          def description
            'Par Shell'
          end

          def active?
            pending_shell_for?(current_entity) && !@finished
          end

          def choices
            return {} unless @game.pending_shell

            PARS.to_h { |p| [p.to_s, @game.format_currency(p).to_s] }
          end

          def choice_name
            'Select par price for the shell'
          end

          def process_choose(action)
            parent = action.entity
            raise GameError, 'No pending shell to par' unless (ps = @game.pending_shell)

            shell = ps[:shell]
            raise GameError, 'You are not the parent of the pending shell' unless ps[:parent] == parent

            par = action.choice.to_i
            raise GameError, 'Invalid par price' unless PARS.include?(par)

            @game.par_and_sell_president_to_parent(shell, parent, par)
            @finished = true
          end

          private

          def pending_shell_for?(entity)
            ps = @game.pending_shell
            ps && ps[:parent] == entity && ps[:shell]
          end
        end
      end
    end
  end
end
