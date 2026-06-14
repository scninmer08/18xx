# frozen_string_literal: true

require_relative '../../../round/auction'

module Engine
  module Game
    module G18IL
      module Round
        class Auction < Engine::Round::Auction
          def self.name = 'Auction'
          def self.short_name = 'AR'
        end
      end
    end
  end
end
