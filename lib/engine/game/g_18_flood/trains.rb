# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Trains
        TRAINS = [
          { name: '4A', distance: 4, price: 100, obsolete_on: '4', num: 99, no_local: false },
          { name: '4B', distance: 4, price: 200, obsolete_on: '5', num: 99, no_local: false },
          { name: '4C', distance: 4, price: 300, obsolete_on: '6', num: 99, no_local: false },
          { name: '4D', distance: 4, price: 400, obsolete_on: '8', num: 99, no_local: false },
          { name: '4E', distance: 4, price: 600, num: 99, no_local: false },
          { name: '4F', distance: 4, price: 800, num: 99, no_local: false },
          { name: 'INF', distance: 99, price: 0, reserved: true, num: 3, no_local: false },
         ].freeze
      end
    end
  end
end
