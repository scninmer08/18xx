# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Bot
        class PolicyProfile
          DEFAULTS = {
            token_score_threshold: 25,
            auction_cash_reserve: 180,
            concession_cash_reserve: 160,
            concession_values: { 2 => 20, 5 => 35, 10 => 45 },
            attached_private_value: 5,
            private_values: { A: 55, B: 40 },
            par_values: { 40 => 0, 60 => 0, 80 => 0, 100 => 0, 120 => 0, 150 => 0 },
            presidency_penalty: 0,
            train_count_penalty: 0,
            conversion_values: { 2 => 0, 5 => 0 },
            dividend_values: { payout: 0, half: 0, withhold: 0 },
            private_acquisition_threshold: 0,
            private_president_bonus: 0,
            stock_own_corporation_bonus: 0,
            stock_market_bonus: 0,
            stock_treasury_bonus: 0,
            stock_price_weight: 0,
            train_cash_reserve: 30,
            train_capacity_weight: 25,
            train_permanent_bonus: 80,
            train_price_divisor: 11,
            train_exchange_bonus: 20,
            track_neighbor_weight: 25,
            track_new_exit_weight: 10,
            track_revenue_weight: 2,
            track_city_weight: 15,
            track_ic_line_weight: 40,
            track_home_bonus: 400,
            token_revenue_weight: 2,
            token_path_weight: 8,
            token_slot_weight: 5,
            token_chicago_bonus: 45,
            token_st_louis_bonus: 40,
            token_ic_line_bonus: 25,
            token_replacement_bonus: 10,
          }.freeze

          MUTATION_RANGES = {
            token_score_threshold: [0, 100, 5],
            auction_cash_reserve: [0, 400, 10],
            concession_cash_reserve: [80, 400, 10],
            attached_private_value: [0, 50, 5],
            presidency_penalty: [-150, 150, 5],
            train_count_penalty: [-150, 150, 5],
            private_acquisition_threshold: [-150, 150, 5],
            private_president_bonus: [-150, 150, 5],
            stock_own_corporation_bonus: [-150, 150, 5],
            stock_market_bonus: [-150, 150, 5],
            stock_treasury_bonus: [-150, 150, 5],
            stock_price_weight: [-10, 10, 1],
            train_cash_reserve: [0, 200, 10],
            train_capacity_weight: [5, 60, 5],
            train_permanent_bonus: [0, 200, 10],
            train_price_divisor: [2, 30, 1],
            train_exchange_bonus: [0, 100, 5],
            track_neighbor_weight: [0, 80, 5],
            track_new_exit_weight: [0, 50, 2],
            track_revenue_weight: [0, 10, 1],
            track_city_weight: [0, 60, 5],
            track_ic_line_weight: [0, 100, 5],
            track_home_bonus: [0, 1_000, 50],
            token_revenue_weight: [0, 10, 1],
            token_path_weight: [0, 30, 2],
            token_slot_weight: [0, 20, 1],
            token_chicago_bonus: [0, 100, 5],
            token_st_louis_bonus: [0, 100, 5],
            token_ic_line_bonus: [0, 100, 5],
            token_replacement_bonus: [0, 50, 5],
          }.freeze

          HASH_MUTATION_RANGES = {
            concession_values: [0, 150, 5],
            private_values: [0, 150, 5],
            par_values: [-150, 150, 5],
            conversion_values: [-150, 150, 5],
            dividend_values: [-150, 150, 5],
          }.freeze

          attr_reader :name, :settings

          def initialize(name: 'Balanced', **overrides)
            @name = name
            @settings = DEFAULTS.merge(overrides).transform_values do |value|
              value.is_a?(Hash) || value.is_a?(Array) ? value.dup.freeze : value
            end.freeze
          end

          def [](key)
            settings.fetch(key)
          end

          def with(name:, **overrides)
            self.class.new(name: name, **settings.merge(overrides))
          end

          def to_h
            { name: name, settings: settings }
          end

          def mutate(seed:, name:, magnitude: 0.2)
            random = Random.new(seed)
            mutation_rate = [[magnitude * 2, 0.2].max, 0.8].min
            mutations = {}

            MUTATION_RANGES.each do |key, range|
              next unless random.rand < mutation_rate

              mutations[key] = mutate_number(settings[key], range, magnitude, random)
            end
            HASH_MUTATION_RANGES.each do |key, range|
              values = settings[key].transform_values do |value|
                random.rand < mutation_rate ? mutate_number(value, range, magnitude, random) : value
              end
              mutations[key] = values if values != settings[key]
            end
            if mutations.empty?
              key, range = MUTATION_RANGES.to_a.sample(random: random)
              mutations[key] = mutate_number(settings[key], range, magnitude, random)
            end

            with(name: name, **mutations)
          end

          def self.random(seed:, name: 'Random Explorer')
            random = Random.new(seed)
            settings = DEFAULTS.merge(MUTATION_RANGES.transform_values { |range| random_number(range, random) })
            HASH_MUTATION_RANGES.each do |key, range|
              settings[key] = DEFAULTS.fetch(key).transform_values { random_number(range, random) }
            end
            new(name: name, **settings)
          end

          def self.starter_set
            [
              new,
              new(
                name: 'Financier',
                concession_cash_reserve: 220,
                concession_values: { 2 => 15, 5 => 25, 10 => 40 },
                presidency_penalty: 60,
                train_cash_reserve: 70,
                train_permanent_bonus: 100,
              ),
              new(
                name: 'Expansionist',
                auction_cash_reserve: 140,
                concession_cash_reserve: 160,
                concession_values: { 2 => 30, 5 => 50, 10 => 70 },
                presidency_penalty: -40,
                train_cash_reserve: 20,
              ),
              new(
                name: 'Engineer',
                train_capacity_weight: 30,
                train_permanent_bonus: 110,
                track_neighbor_weight: 35,
                track_new_exit_weight: 18,
                track_revenue_weight: 3,
                track_ic_line_weight: 55,
                token_score_threshold: 15,
              ),
            ]
          end

          def self.from_h(data)
            name = data[:name] || data['name']
            raw_settings = data[:settings] || data['settings'] || {}
            settings = raw_settings.transform_keys(&:to_sym)
            settings[:concession_values] = settings[:concession_values].transform_keys(&:to_i) if settings[:concession_values]
            settings[:private_values] = settings[:private_values].transform_keys(&:to_sym) if settings[:private_values]
            %i[par_values conversion_values].each do |key|
              settings[key] = settings[key].transform_keys(&:to_i) if settings[key]
            end
            settings[:dividend_values] = settings[:dividend_values].transform_keys(&:to_sym) if settings[:dividend_values]
            new(name: name, **settings)
          end

          def self.random_number(range, random)
            minimum, maximum, step = range
            minimum + (random.rand(((maximum - minimum) / step) + 1) * step)
          end

          private

          def mutate_number(value, range, magnitude, random)
            minimum, maximum, step = range
            scale = [value.abs, (maximum - minimum) / 4].max
            step_count = [(scale * magnitude / step).round, 1].max
            delta = random.rand(-step_count..step_count)
            delta = random.rand(2).zero? ? -1 : 1 if delta.zero?
            [[value + (delta * step), minimum].max, maximum].min
          end
        end
      end
    end
  end
end
