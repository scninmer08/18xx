# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      class StockMarket < Engine::StockMarket
        attr_writer :game

        def move(corporation, coordinates, force: false)
          return super unless corporation == @game.ic

          # IC may not move unless it owns a train
          return if @game.ic.presidents_share.owner == @game.ic

          share_price = share_price(coordinates)
          # IC may never close
          return super unless share_price.types.include?(:close)

          @game.log << "#{@game.ic.name} may not close"
        end
      end
    end
  end
end
