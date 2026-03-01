# frozen_string_literal: true

require_relative '../../../round/auction'

module Engine
  module Game
    module G18FLOOD
      module Round
        class Auction < Engine::Round::Auction
          def self.name = 'Stock'
          def self.short_name = 'SR'
        end
      end
    end
  end
end
