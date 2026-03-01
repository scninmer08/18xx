# frozen_string_literal: true

require_relative '../../../round/auction'

module Engine
  module Game
    module G18IL
      module Round
        class Auction < Engine::Round::Auction
          def self.name = 'Concession'
          def self.short_name = 'CR'
        end
      end
    end
  end
end
