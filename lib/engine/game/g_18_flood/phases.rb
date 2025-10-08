# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      module Phases
        PHASES = [
              {
                name: 'A',
                train_limit: 99,
                tiles: %i[yellow green brown gray purple],
                operating_rounds: 3,
              },
              {
                name: 'B',
                train_limit: 99,
                tiles: %i[yellow green brown gray purple],
                operating_rounds: 2,
              },
              {
                name: 'C',
                train_limit: 99,
                tiles: %i[yellow green brown gray purple],
                operating_rounds: 2,
              },
              {
                name: 'D',
                train_limit: 99,
                tiles: %i[yellow green brown gray purple],
                operating_rounds: 2,
              },
              {
                name: 'E',
                train_limit: 99,
                tiles: %i[yellow green brown gray purple],
                operating_rounds: 2,
              },
              {
                name: 'F',
                train_limit: 99,
                tiles: %i[yellow green brown gray purple],
                operating_rounds: 1,
              },
            ].freeze
      end
    end
  end
end
