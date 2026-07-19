# frozen_string_literal: true

require_relative '../../../round/stock'

module Engine
  module Game
    module G1872
      module Round
        class Auction < Engine::Round::Stock
          def name
            'Auction Round'
          end

          def self.short_name
            'AR'
          end

          def self.round_name
            'Auction Round'
          end

          def stock?
            false
          end

          def auction?
            true
          end

          def setup
            skip_steps
            next_entity! unless active_step
          end

          def after_process(_action)
            return if active_step

            next_entity!
          end

          def next_entity!
            if finished?
              next_entity_index!
              return
            end

            next_entity_index!
            start_entity
          end

          def start_entity
            @steps.each(&:unpass!)

            skip_steps
            next_entity! unless active_step
          end

          def finished?
            @game.finished || @entities.all?(&:passed?)
          end

          protected

          def finish_round; end
        end
      end
    end
  end
end
