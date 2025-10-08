# lib/engine/game/g_18_flood/step/token.rb
# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Step
        class Token < Engine::Step::Token
          def actions(entity)
            return [] if @game.shell_corporation?(entity)

            super
          end

          def process_place_token(action)
            entity = action.entity

            if !@game.loading && !available_hex(entity, action.city.hex)
              raise GameError, "#{entity.name} cannot place token in City "\
                               "#{action.city.id} on hex #{action.city.hex.id}"
            end

            place_token(entity, action.city, action.token, same_hex_allowed: true)
            pass!

            corp = action.entity
            return unless corp&.corporation?

            price = Engine::Game::G18FLOOD::Corporations::TOKEN_COST
            corp.tokens << Engine::Token.new(corp, price: price)

            @game.graph&.clear_graph_for_all
          end

          def log_skip(entity)
            return if @game.shell_corporation?(entity)

            super
          end
        end
      end
    end
  end
end
