# frozen_string_literal: true

require_relative '../../../step/special_token'

module Engine
  module Game
    module G1872
      module Step
        class SpecialToken < Engine::Step::SpecialToken
          def adjust_token_price_ability!(entity, token, hex, city, special_ability: nil)
            normal_price = token.price
            token, ability = super
            token.price = normal_price if ability == special_ability && ability.price(token).nil?
            [token, ability]
          end
        end
      end
    end
  end
end
