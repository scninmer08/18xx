# frozen_string_literal: true

require_relative '../../../step/home_token'

module Engine
  module Game
    module G18IL
      module Step
        class HomeToken < Engine::Step::HomeToken
          TOKEN_REPLACEMENT_COST = 40

          def available_hex(_entity, hex)
            pending_token[:hexes].include?(hex)
          end

          def can_replace_token?(entity, token)
            @game.home_token_locations(entity).include?(token.city.hex)
          end

          def process_place_token(action)
            hex = action.city.hex
            unless available_hex(action.entity, hex)
              raise GameError, "Cannot place token on #{hex.name} as '\
              'the hex is not available"
            end

            if @game.eligible_tokens?(action.entity)
              replace_token(action)
            else
              token = action.entity.tokens.reject(&:used).first
              place_token(action.entity, action.city, token, connected: false, extra_action: true)
            end
            action.entity.coordinates ||= action.entity.tokens.first&.hex&.id
            @round.pending_tokens.shift
          end

          def replace_token(action)
            hex = action.city.hex
            token = action.entity.tokens.find { |t| t.hex == hex }
            token.status = nil
            @log << "#{action.entity.name} flips token in #{hex.name}"
          end
        end
      end
    end
  end
end
