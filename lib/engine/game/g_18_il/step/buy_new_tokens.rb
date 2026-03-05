# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class BuyNewTokens < Engine::Step::Base
          def actions(entity)
            return [] unless entity == pending_entity

            %w[choose]
          end

          def active?
            pending_entity
          end

          def active_entities
            [pending_entity]
          end

          def pending_entity
            pending_buy[:entity]
          end

          def pending_price
            pending_buy[:price]
          end

          def pending_first_price
            pending_buy[:first_price]
          end

          def pending_type
            pending_buy[:type]
          end

          def available_hex(entity, hex)
            @game.token_graph_for_entity(entity).reachable_hexes(entity)[hex]
          end

          def pending_min
            pending_buy[:min]
          end

          def pending_max
            pending_buy[:max]
          end

          def pending_corp
            pending_buy[:corp] || pending_entity
          end

          def pending_buy
            @round.buy_tokens&.first || {}
          end

          def description
            'Buy New Tokens'
          end

          def process_choose(action)
            num = action.choice.to_i
            total = price(num)
            entity = pending_entity
            @round.buy_tokens.shift # if num > 0
            @game.purchase_tokens!(entity, num, total) if num.positive?
          end

          def choice_available?(entity)
            pending_entity == entity
          end

          def choice_name
            return "Number of additional tokens to buy for #{pending_corp.name}" unless pending_type == :start

            "Number of tokens to buy for #{pending_corp.name}"
          end

          def price(num)
            return 0 if num.zero? || (!@game.intro_game? && pending_entity == @game.station_subsidy.owner)

            pending_first_price + ((num - 1) * pending_price)
          end

          def choices
            Array.new(pending_max - pending_min + 1) do |i|
              num = i + pending_min
              total = price(num)
              next if (num > pending_min) && (total > pending_corp.cash)

              emr = total > pending_corp.cash ? ' - EMR' : ''
              [num, "#{num} (#{@game.format_currency(total)}#{emr})"]
            end.compact.to_h
          end

          def visible_corporations
            [pending_corp]
          end

          def round_state
            super.merge(
              {
                buy_tokens: [],
              }
            )
          end
        end
      end
    end
  end
end
