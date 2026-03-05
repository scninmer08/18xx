# frozen_string_literal: true

require_relative '../../../step/special_buy'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialBuy < Engine::Step::SpecialBuy
          attr_reader :port_marker

          def buyable_items(entity)
            return [] if entity != current_entity
            return [] if entity.cash < @game.class::PORT_MARKER_COST
            return [] if @game.last_set
            return [] if @round.active_step.is_a?(G18IL::Step::BuyTrain)
            return [@port_marker] if @game.loading || !@game.owns_port_marker?(entity)

            []
          end

          def short_description
            'Port Marker'
          end

          def process_special_buy(action)
            corp = action.entity
            raise GameError, "Cannot buy unknown item: #{action.item.description}" if action.item != @port_marker

            cost = @game.class::PORT_MARKER_COST
            @log << "#{corp.name} buys a port marker for #{@game.format_currency(cost)}"
            corp.spend(cost, @game.bank)
            @game.assign_port_icon(corp)
          end

          def setup
            super
            @port_marker ||= Item.new(description: 'Port Marker', cost: @game.class::PORT_MARKER_COST)
          end
        end
      end
    end
  end
end
