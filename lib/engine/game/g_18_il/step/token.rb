# frozen_string_literal: true

require_relative '../../../step/token'

module Engine
  module Game
    module G18IL
      module Step
        class Token < Engine::Step::Token
          TOKEN_REPLACEMENT_COST = 40
          ACTIONS = %w[place_token pass].freeze

          def process_place_token(action)
            entity = action.entity
            city   = action.city
            token  = action.token

            if action.respond_to?(:slot) && (idx = action.slot) && ((clicked = city.tokens[idx])&.status == :flipped)
              replace_flipped_token(entity, city, token, clicked)
              return
            end

            super
          end

          def actions(entity)
            return [] if @game.last_set
            return [] unless entity == current_entity
            return [] unless can_place_token?(entity)
            return [] if entity == @game.ic && @game.ic_in_receivership?
            return [] unless @game.hexes.find { |hex| available_hex(entity, hex) }

            ACTIONS
          end

          def can_replace_token?(entity, token)
            available_hex(entity, token.city.hex) || token.status == :flipped
          end

          def available_hex(entity, hex)
            if entity.tokens.all?(&:used)
              nodes = []
              hex.tile.cities.each { |city| nodes << @game.token_graph_for_entity(entity).connected_nodes(entity)[city] }
              return false if nodes.none?

              entity.tokens.select { |t| t.status == :flipped }.map(&:hex).include?(hex)
            else
              @game.graph.reachable_hexes(entity)[hex]
            end
          end

          def pass_description = 'Pass (Token)'

          def can_place_token?(entity)
            (current_entity == entity &&
              !@round.tokened &&
              !available_tokens(entity).empty? &&
              @game.graph.can_token?(entity)) ||
              entity.tokens.any? { |t| t.status == :flipped } ||
              (!@game.intro_game? &&
               !@game.private_used?(@game.company_by_id('USY')) &&
               entity == @game.company_by_id('USY').owner)
          end

          def available_tokens(entity)
            token_holder = entity.company? ? entity.owner : entity
            token_holder.tokens.reject { |t| t.used && t.status != :flipped }.uniq(&:type)
          end

          def replace_flipped_token(entity, city, _token, flipped_token, _stl_hex = false)
            hex = city.hex
            if entity.cash < TOKEN_REPLACEMENT_COST
              raise GameError, 'Insufficient cash to replace flipped token ' \
                               "(needs #{@game.format_currency(TOKEN_REPLACEMENT_COST)}, " \
                               "has #{@game.format_currency(entity.cash)})"
            end

            payee, verb = flipped_token.corporation == entity ? [@game.bank, 'flips'] : [flipped_token.corporation, 'replaces']
            entity.spend(TOKEN_REPLACEMENT_COST, payee)
            @log << "#{entity.name} pays #{@game.format_currency(TOKEN_REPLACEMENT_COST)} to " \
                    "#{payee.name} and #{verb} its token in #{hex.name} (#{hex.tile.location_name})"
            @game.payoff_loan(payee) if payee.corporation? && payee.loans.any?

            flipped_token.status = nil
            flipped_token.remove!

            city.place_token(entity, entity.tokens.reject(&:used).first, free: true, check_tokenable: false)
            @round.tokened = true
          end

          def place_token(entity, city, token, connected: true, extra_action: false, special_ability: nil, check_tokenable: true)
            hex = city.hex
            flipped_token = hex.tile.cities.filter_map { |c| c.tokens.find { |t| t&.status == :flipped } }.first

            check_connected(entity, city, hex) if connected
            if should_replace_flipped_token?(entity, city, flipped_token)
              replace_flipped_token(entity, city, token, flipped_token)
              return
            end
            raise GameError, "Must flip one of the corporation's abandoned stations" if entity.tokens.all?(&:used)

            super
          end

          def should_replace_flipped_token?(entity, city, flipped_token)
            return false unless flipped_token
            return false unless city.available_slots.zero?
            return false if city.reserved_by?(entity)

            city.hex.tile.cities.none? do |c|
              c.tokens.any? { |t| t&.corporation == entity && t&.status != :flipped }
            end
          end
        end
      end
    end
  end
end
