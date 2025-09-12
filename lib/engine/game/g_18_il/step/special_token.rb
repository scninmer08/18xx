# frozen_string_literal: true

require_relative '../../../step/special_token'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialToken < Engine::Step::SpecialToken
          def process_place_token(action)
            super

            entity = action.entity
            @game.log << "#{entity.name} closes"
            entity.close!
          end
        end
      end
    end
  end
end
