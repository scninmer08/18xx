# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class IcFormationCheck < Engine::Step::Base
          def description
            'IC Formation Check'
          end

          def actions(_entity)
            []
          end

          def active?
            true
          end

          def blocks?
            true
          end

          def log_skip(entity); end

          def skip!
            @game.event_ic_formation! if @game.ic_formation_pending?
            super
          end
        end
      end
    end
  end
end
