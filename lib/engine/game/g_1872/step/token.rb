# frozen_string_literal: true

require_relative '../../../step/token'

module Engine
  module Game
    module G1872
      module Step
        class Token < Engine::Step::Token
          OO_HOME_CORPORATIONS = {
            'B38' => 'C&NW',
            'H42' => 'KATY',
          }.freeze

          def available_hex(entity, hex)
            return false unless oo_home_token_placed?(hex)

            super
          end

          private

          def oo_home_token_placed?(hex)
            corporation_id = OO_HOME_CORPORATIONS[hex.id]
            return true unless corporation_id

            @game.corporation_by_id(corporation_id).tokens.first&.used
          end
        end
      end
    end
  end
end
