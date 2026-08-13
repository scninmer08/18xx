# frozen_string_literal: true

require_relative '../../../step/special_token'

module Engine
  module Game
    module G1872
      module Step
        class SpecialToken < Engine::Step::SpecialToken
          def actions(entity)
            return [] if entity&.company? && entity.owner&.corporation? && @game.isolated_branch?(entity.owner)
            return [] if entity.id == 'BCLC' && !hays_laid?

            super
          end

          def description
            return 'Use Big Creek Land Company' if active_entities.any? { |entity| entity.id == 'BCLC' }

            super
          end

          def process_place_token(action)
            if action.entity.id == 'BCLC'
              @game.use_big_creek_land_company!(action.entity.owner, city: action.city)
              return
            end

            super
          end

          def adjust_token_price_ability!(entity, token, hex, city, special_ability: nil)
            normal_price = token.price
            token, ability = super
            token.price = normal_price if ability == special_ability && ability.price(token).nil?
            [token, ability]
          end

          private

          def hays_laid?
            @game.hex_by_id('H26').tile.color != :white
          end
        end
      end
    end
  end
end
