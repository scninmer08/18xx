# frozen_string_literal: true

require_relative '../../../step/special_token'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialToken < Engine::Step::SpecialToken
          def process_place_token(action)
            token_ability = ability(action.entity)
            company = token_ability&.owner

            super

            @game.flip_private!(company) if token_ability&.count&.zero?
          end
        end
      end
    end
  end
end
