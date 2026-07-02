# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Bot
        class EvolutionResult
          attr_reader :initial_profile, :champion, :generations, :holdout

          def initialize(initial_profile:, champion:, generations:, holdout:)
            @initial_profile = initial_profile
            @champion = champion
            @generations = generations
            @holdout = holdout
          end

          def to_h
            {
              initial_profile: initial_profile.to_h,
              champion: champion.to_h,
              generations: generations.map do |generation|
                {
                  generation: generation[:generation],
                  parent: generation[:parent],
                  winner: generation[:winner],
                  winner_standing: generation[:winner_standing],
                  tournament: generation[:tournament].to_h,
                  evaluations: generation[:evaluations].map do |evaluation|
                    {
                      candidate: evaluation[:candidate],
                      standing: evaluation[:standing],
                      tournament: evaluation[:tournament].to_h,
                    }
                  end,
                }
              end,
              holdout: holdout.to_h,
            }
          end

          def format
            lines = [
              '18IL Bot Evolution Report',
              "Initial profile: #{initial_profile.name}",
              "Generations: #{generations.size}",
              '',
              'Generation winners:',
            ]
            generations.each do |generation|
              standing = generation[:winner_standing]
              lines << "  #{generation[:generation]}. #{generation[:winner]} " \
                       "(#{standing[:points]} points, average rank #{standing[:average_rank]})"
            end
            lines.concat([
                           '',
                           "Champion: #{champion.name}",
                           "Champion settings: #{champion.settings}",
                           '',
                           'Holdout standings:',
                         ])
            holdout.standings.each_with_index do |standing, index|
              lines << "  #{index + 1}. #{standing[:profile]}: #{standing[:points]} points, " \
                       "#{standing[:wins]} wins, average rank #{standing[:average_rank]}, " \
                       "average value #{standing[:average_value]}"
            end
            lines.join("\n")
          end
        end

        class EvolutionRunner
          attr_reader :initial_profile, :generations, :mutations, :training_seeds, :holdout_seeds,
                      :first_seed, :holdout_first_seed, :optional_rules, :max_actions, :magnitude, :on_game

          def initialize(initial_profile:, generations:, mutations:, training_seeds:, holdout_seeds:, first_seed:,
                         holdout_first_seed:, optional_rules:, max_actions:, magnitude:, on_game: nil)
            raise ArgumentError, 'generations must be positive' unless generations.positive?
            raise ArgumentError, 'mutations must be between 1 and 5' unless (1..5).cover?(mutations)
            raise ArgumentError, 'training_seeds must be positive' unless training_seeds.positive?
            raise ArgumentError, 'holdout_seeds must be positive' unless holdout_seeds.positive?
            raise ArgumentError, 'magnitude must be positive' unless magnitude.positive?

            @initial_profile = initial_profile
            @generations = generations
            @mutations = mutations
            @training_seeds = training_seeds
            @holdout_seeds = holdout_seeds
            @first_seed = first_seed
            @holdout_first_seed = holdout_first_seed || (first_seed + (generations * training_seeds) + 1_000)
            @optional_rules = optional_rules
            @max_actions = max_actions
            @magnitude = magnitude
            @on_game = on_game
          end

          def run
            champion = initial_profile
            generation_results = Array.new(generations) do |index|
              generation = index + 1
              parent = champion
              candidates = [parent] + Array.new(mutations) do |mutation_index|
                mutation_number = mutation_index + 1
                seed = mutation_seed(generation, mutation_number)
                if mutation_number == mutations
                  PolicyProfile.random(seed: seed, name: "Generation #{generation} Global Explorer")
                else
                  parent.mutate(
                    seed: seed,
                    name: "Generation #{generation} Mutation #{mutation_number}",
                    magnitude: magnitude,
                  )
                end
              end
              evaluations = candidates.map.with_index do |candidate, candidate_index|
                tournament = run_tournament(
                  profiles: evaluation_profiles(candidate, generation),
                  seeds: training_seeds,
                  first_seed: first_seed + (index * training_seeds),
                  stage: "generation #{generation}, candidate #{candidate_index + 1}/#{candidates.size}",
                )
                ensure_complete!(tournament, "generation #{generation}, candidate #{candidate.name}")
                {
                  candidate: candidate.name,
                  profile: candidate,
                  standing: tournament.standings.find { |standing| standing[:profile] == 'Candidate' },
                  tournament: tournament,
                }
              end
              winner = evaluations.max_by { |evaluation| standing_score(evaluation[:standing]) }
              champion = winner[:profile]
              {
                generation: generation,
                parent: parent.name,
                winner: champion.name,
                winner_standing: winner[:standing],
                tournament: winner[:tournament],
                evaluations: evaluations,
              }
            end

            holdout = run_tournament(
              profiles: holdout_profiles(champion),
              seeds: holdout_seeds,
              first_seed: holdout_first_seed,
              stage: 'holdout',
            )
            ensure_complete!(holdout, 'holdout')
            EvolutionResult.new(
              initial_profile: initial_profile,
              champion: champion,
              generations: generation_results,
              holdout: holdout,
            )
          end

          private

          def ensure_complete!(tournament, stage)
            incomplete = tournament.games.reject { |game| game[:status] == 'finished' }
            return if incomplete.empty?

            details = incomplete.map do |game|
              detail = "seed #{game[:seed]}, rotation #{game[:rotation]}: #{game[:status]} - #{game[:detail]}"
              game[:backtrace]&.first ? "#{detail} (#{game[:backtrace].first})" : detail
            end
            raise "#{stage} has incomplete games: #{details.join('; ')}"
          end

          def mutation_seed(generation, mutation)
            (first_seed * 10_000) + (generation * 100) + mutation
          end

          def standing_score(standing)
            [standing[:points], -standing[:average_rank], standing[:average_value]]
          end

          def run_tournament(profiles:, seeds:, first_seed:, stage:)
            TournamentRunner.new(
              profiles: profiles,
              seeds: seeds,
              first_seed: first_seed,
              optional_rules: optional_rules,
              max_actions: max_actions,
              on_game: lambda do |number, total, summary|
                on_game&.call(stage, number, total, summary)
              end,
            ).run
          end

          def holdout_profiles(champion)
            [champion.with(name: 'Evolved Champion')] + reference_profiles(generations).map.with_index do |profile, index|
              profile.with(name: "Reference #{index + 1}: #{profile.name}")
            end
          end

          def evaluation_profiles(candidate, generation)
            [candidate.with(name: 'Candidate')] + reference_profiles(generation).map.with_index do |profile, index|
              profile.with(name: "Reference #{index + 1}: #{profile.name}")
            end
          end

          def reference_profiles(generation)
            others = PolicyProfile.starter_set.reject { |profile| profile.name == initial_profile.name }
            selected = others.rotate((generation - 1) % others.size).take(2)
            [initial_profile] + selected
          end
        end
      end
    end
  end
end
