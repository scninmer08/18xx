# frozen_string_literal: true

require_relative '../../../step/special_token'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialToken < Engine::Step::SpecialToken
          def actions(entity)
            return super unless gtl?(entity)
            return [] if @game.private_used?(entity)

            actions = []
            actions << 'place_token' if gtl_token_placeable?(entity)
            actions << 'pass'
            actions
          end

          def pass_description
            return 'Use GTL (No Token)' if gtl?(current_entity)

            super
          end

          def process_place_token(action)
            token_ability = ability(action.entity)
            company = token_ability&.owner

            if gtl?(action.entity)
              raise GameError, "#{action.entity.name} cannot place a token in Chicago" unless gtl_token_placeable?(action.entity)

              @game.use_gtl!(action.entity.owner, flip: false)
            end

            super

            return if !gtl?(company) && !token_ability&.count&.zero?

            @game.flip_private!(company)
          end

          def process_pass(action)
            return super unless gtl?(action.entity)

            @game.use_gtl!(action.entity.owner)
          end

          def ability(entity)
            return super unless gtl?(entity)

            @game.abilities(entity, :token, time: 'owning_corp_or_turn') do |ability, _company|
              return ability
            end

            nil
          end

          private

          def gtl?(entity)
            entity == @game.company_by_id('GTL')
          end

          def gtl_token_placeable?(company)
            token_ability = ability(company)
            return false unless token_ability

            corp = company.owner
            return false unless corp

            tokens = available_tokens(company)
            return false if tokens.empty?

            city = @game.hex_by_id(@game.class::CHICAGO_HEX.first).tile.cities.find { |c| c.index == token_ability.city }
            return false unless city

            city.tokenable?(corp, free: true, tokens: tokens)
          end
        end
      end
    end
  end
end
