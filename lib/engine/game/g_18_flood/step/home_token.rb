# frozen_string_literal: true

require_relative '../../../step/home_token'

module Engine
  module Game
    module G18FLOOD
      module Step
        class HomeToken < Engine::Step::HomeToken
          def description
            pending_shell_swap? ? 'Replace a Parent Token with Shell Token' : super
          end

          def actions(entity)
            return [] unless entity == pending_entity
            return %w[place_token] if pending_shell_swap?

            super
          end

          def active?
            pending_shell_swap? || super
          end

          def active_entities
            return [pending_entity] if pending_shell_swap?

            super
          end

          def available_hex(_entity, hex)
            return super unless pending_shell_swap?

            parent   = pending_token[:parent]
            home_ids = Array(parent&.coordinates).compact

            return false if home_ids.include?(hex.id)

            pending_token[:hexes].include?(hex)
          end

          def can_replace_token?(_entity, _token)
            pending_shell_swap? || super
          end

          def can_place_token?(entity)
            return true if pending_shell_swap? && entity == pending_entity

            super
          end

          def help
            ['Replace a parent token with a shell token:']
          end

          def process_place_token(action)
            if pending_shell_swap?
              shell   = pending_token[:entity]
              parent  = pending_token[:parent]
              shell_t = pending_token[:token]
              city    = action.city
              hex     = city.hex

              unless pending_token[:hexes].include?(hex)
                raise GameError, "Cannot place token on #{hex.name} as the hex is not available"
              end

              idx = city.tokens.index { |t| t&.corporation == parent }
              raise GameError, "No #{parent.name} token to replace in #{hex.name}" unless idx

              parent_token = city.tokens[idx]

              parent_token.remove!
              parent.tokens.delete(parent_token)

              shell_t ||= (shell.tokens.find { |t| !t.used } || Engine::Token.new(shell, price: 0).tap { |t| shell.tokens << t })

              city.place_token(shell, shell_t, check_tokenable: false)

              @log << "#{shell.name} replaces #{parent.name}'s token in #{hex.name}"

              @round.pending_tokens.shift
              @game.begin_shell_post_swap_shares!(shell)
              @game.graph.clear_graph_for_all
            else
              super
            end
          end

          def pending_shell_swap?
            pt = pending_token
            pt && pt[:entity]&.corporation? && pt[:entity].type == :shell && pt[:parent]&.corporation?
          end
        end
      end
    end
  end
end
