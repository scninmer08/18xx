# frozen_string_literal: true

require_relative '../../../step/special_buy'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialBuy < Engine::Step::SpecialBuy
          attr_reader :port_permit, :stl_permit

          def buyable_items(entity)
            return [] if entity != current_entity
            return [] if entity.cash < [@game.class::PORT_PERMIT_COST, @game.class::STL_PERMIT_COST].min
            return [] if @game.last_set
            return [] if @round.active_step.is_a?(G18IL::Step::BuyTrain)

            items = []
            items << @port_permit if @game.loading || (!@game.owns_port_permit?(entity) &&
              @game.port_permit_available?(entity) && @game.route_to_chicago?(entity))
            items << @stl_permit if @game.loading || (!@game.stl_permit?(entity) &&
              @game.stl_permit_available? && @game.route_to_stl?(entity))
            items.select { |item| entity.cash >= item.cost }
          end

          def short_description
            'Port Permit'
          end

          def process_special_buy(action)
            corp = action.entity
            case action.item
            when @port_permit
              if !@game.loading && !@game.route_to_chicago?(corp)
                raise GameError, "#{corp.name} must have a route to Chicago to buy a port permit"
              end

              cost = @game.class::PORT_PERMIT_COST
              @log << "#{corp.name} buys a port permit for #{@game.format_currency(cost)}"
              corp.spend(cost, @game.bank)
              @game.assign_port_permit(corp)
            when @stl_permit
              if !@game.loading && !@game.route_to_stl?(corp)
                raise GameError, "#{corp.name} must have a route to St. Louis to buy an STL permit"
              end

              cost = @game.class::STL_PERMIT_COST
              @log << "#{corp.name} buys an STL permit for #{@game.format_currency(cost)}"
              corp.spend(cost, @game.bank)
              @game.assign_stl_permit(corp)
            else
              raise GameError, "Cannot buy unknown item: #{action.item.description}"
            end
          end

          def setup
            super
            @port_permit ||= Item.new(description: 'Port Permit', cost: @game.class::PORT_PERMIT_COST)
            @stl_permit ||= Item.new(description: 'STL Permit', cost: @game.class::STL_PERMIT_COST)
          end
        end
      end
    end
  end
end
