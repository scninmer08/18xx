# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Phases
        PHASES = [
              {
                name: '2',
                train_limit: 4,
                tiles: [:yellow],
                operating_rounds: 2,
              },
              {
                name: '3',
                on: '3',
                train_limit: 4,
                tiles: %i[yellow green],
                operating_rounds: 2,
              },
              {
                name: '4A',
                on: '4',
                train_limit: 3,
                tiles: %i[yellow green],
                operating_rounds: 2,
              },
              {
                name: '5A',
                on: '5',
                train_limit: 3,
                tiles: %i[yellow green brown],
                operating_rounds: 2,
              },
              {
                name: '4B',
                on: '4+2C',
                train_limit: 2,
                tiles: %i[yellow green brown],
                operating_rounds: 2,
              },
              {
                name: '5B',
                on: '5+1C',
                train_limit: 2,
                tiles: %i[yellow green brown],
                operating_rounds: 2,
              },
              {
                name: '8',
                on: '8',
                train_limit: 2,
                tiles: %i[yellow green brown gray],
                operating_rounds: 2,
              },
              {
                name: 'D',
                on: 'D',
                train_limit: 2,
                tiles: %i[yellow green brown gray],
                operating_rounds: 2,
                status: %w[pullman_strike blocking_tokens cert_limit_change],
              },
            ].freeze
      end
    end
  end
end
