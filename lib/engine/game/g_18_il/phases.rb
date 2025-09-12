# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Phases
        STATUS_TEXT = Base::STATUS_TEXT.merge(
          'pullman_strike' => [
            'Pullman Strike',
            '4+2P downgrades to 4; 5+1P downgrades to 5',
          ],
        ).freeze

        PHASES = [
              {
                name: '2',
                train_limit: 4,
                tiles: [:yellow],
                operating_rounds: 2,
                corporation_sizes: [2, 5, 10],
              },
              {
                name: '3',
                on: '3',
                train_limit: 4,
                tiles: %i[yellow green],
                operating_rounds: 2,
                corporation_sizes: [2, 5, 10],
              },
              {
                name: '4A',
                on: '4',
                train_limit: 3,
                tiles: %i[yellow green],
                operating_rounds: 2,
                corporation_sizes: [5, 10],
              },
              {
                name: '4B',
                on: '4+2P',
                train_limit: 2,
                tiles: %i[yellow green brown],
                operating_rounds: 2,
                corporation_sizes: [10],
              },
              {
                name: '5',
                on: '5+1P',
                train_limit: 2,
                tiles: %i[yellow green brown],
                operating_rounds: 2,
                corporation_sizes: [10],
              },
              {
                name: '6',
                on: '6',
                train_limit: 2,
                tiles: %i[yellow green brown],
                operating_rounds: 2,
                corporation_sizes: [10],
              },
              {
                name: 'D',
                on: 'D',
                train_limit: 2,
                tiles: %i[yellow green brown gray],
                operating_rounds: 2,
                corporation_sizes: [10],
                status: ['pullman_strike'],
              },
            ].freeze
      end
    end
  end
end
