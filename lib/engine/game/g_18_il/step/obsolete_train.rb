# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class ObsoleteTrain < Engine::Step::Base
          ACTIONS = %w[choose pass].freeze

          def actions(entity)
            return [] unless entity == po.owner

            ACTIONS
          end

          def description
            "Decide whether to use #{po.name} ability"
          end

          def choice_available?(_entity)
            true
          end

          def choice_name
            "Select a train for #{po.name} to prevent from rusting"
          end

          def choices
            train = trains_rusting_for(po.owner, purchased_train).first
            name = train.name

            # If the name is only digits (e.g. "2" or "3"), format as "2-Train"
            display = name.match?(/^\d+$/) ? "#{name}-Train" : "#{name} Train"

            [display]
          end

          def active_entities
            [po.owner]
          end

          def active?
            @game.pending_rusting_event
          end

          def po
            @po ||= @game.planned_obsolescence
          end

          def purchased_train
            @game.pending_rusting_event[:train]
          end

          def trains_rusting_for(corporation, purchased_train)
            corporation.trains.select { |t| @game.rust?(t, purchased_train) }
          end

          def process_choose(action)
            train = trains_rusting_for(po.owner, purchased_train).first
            train_name = train.name.match?(/^\d+$/) ? "#{train.name}-train" : "#{train.name} train"
            @log << "#{action.entity.name} chooses to use #{po.name} to prevent a #{train_name} " \
                    'from rusting. It becomes obsolete instead'
            train.obsolete_on = purchased_train.sym
            train.rusts_on = nil
            @log << "#{po.name} closes"
            po.close!
            trigger_rusting_event
          end

          def process_pass(action)
            super
            trigger_rusting_event
          end

          def log_pass(entity)
            @log << "#{entity.name} declines to use #{po.name}"
          end

          def trigger_rusting_event
            @game.rust_trains!(purchased_train, @game.pending_rusting_event[:entity])
            @game.pending_rusting_event = nil
          end
        end
      end
    end
  end
end
