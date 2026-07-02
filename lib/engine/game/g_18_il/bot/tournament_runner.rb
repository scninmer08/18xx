# frozen_string_literal: true

require 'json'
unless RUBY_ENGINE == 'opal'
  require 'open3'
  require 'rbconfig'
end

module Engine
  module Game
    module G18IL
      module Bot
        class TournamentResult
          attr_reader :profiles, :seeds, :first_seed, :optional_rules, :games

          def initialize(profiles:, seeds:, first_seed:, optional_rules:, games:)
            @profiles = profiles
            @seeds = seeds
            @first_seed = first_seed
            @optional_rules = optional_rules
            @games = games
          end

          def standings
            results_by_profile = profiles.map do |profile|
              results = games.select { |game| game[:status] == 'finished' }
                .flat_map { |game| game[:results] }
                .select { |result| result[:profile] == profile.name }
              {
                profile: profile.name,
                games: results.size,
                wins: results.count { |result| result[:rank] == 1 },
                points: results.sum { |result| profiles.size - result[:rank] },
                average_rank: average(results.map { |result| result[:rank] }),
                average_value: average(results.map { |result| result[:value] }),
              }
            end
            @standings ||= results_by_profile.sort_by do |standing|
              [-standing[:points], standing[:average_rank], -standing[:average_value]]
            end
          end

          def to_h
            {
              config: {
                profiles: profiles.map(&:to_h),
                seeds: seeds,
                first_seed: first_seed,
                optional_rules: optional_rules,
                games: games.size,
              },
              status_counts: games.group_by { |game| game[:status] }.transform_values(&:size),
              standings: standings,
              games: games,
            }
          end

          def format
            lines = [
              '18IL Bot Tournament',
              "Profiles: #{profiles.map(&:name).join(', ')}",
              "Seeds: #{first_seed}-#{first_seed + seeds - 1} | Games: #{games.size}",
              "Rules: #{optional_rules.empty? ? 'regular game' : optional_rules.join(', ')}",
              "Status: #{to_h[:status_counts].sort.map { |status, count| "#{status}=#{count}" }.join(', ')}",
              '',
              'Standings:',
            ]
            standings.each_with_index do |standing, index|
              lines << "  #{index + 1}. #{standing[:profile]}: #{standing[:points]} points, " \
                       "#{standing[:wins]} wins, average rank #{standing[:average_rank]}, " \
                       "average value #{standing[:average_value]}"
            end

            failures = games.reject { |game| game[:status] == 'finished' }
            unless failures.empty?
              lines << ''
              lines << 'Incomplete games:'
              failures.each do |game|
                lines << "  Seed #{game[:seed]}, rotation #{game[:rotation]}: " \
                         "#{game[:status]} - #{game[:detail]}"
              end
            end
            lines.join("\n")
          end

          private

          def average(values)
            return 0 if values.empty?

            (values.sum.to_f / values.size).round(2)
          end
        end

        class TournamentRunner
          WORKER_SCRIPT = <<~'RUBY'.freeze
            require 'engine/logger'
            Engine::Logger.set_level(Logger::FATAL)
            require 'require_all'
            require_all 'lib/engine/game/g_18_il'
            puts JSON.generate(Engine::Game::G18IL::Bot::TournamentWorker.run($stdin.read))
          RUBY

          attr_reader :profiles, :seeds, :first_seed, :optional_rules, :max_actions, :on_game

          def initialize(profiles:, seeds:, first_seed:, optional_rules:, max_actions:, on_game: nil)
            raise ArgumentError, 'At least two profiles are required' if profiles.size < 2
            raise ArgumentError, 'Profile names must be unique' unless profiles.map(&:name).uniq.size == profiles.size
            raise ArgumentError, 'seeds must be positive' unless seeds.positive?

            @profiles = profiles
            @seeds = seeds
            @first_seed = first_seed
            @optional_rules = optional_rules
            @max_actions = max_actions
            @on_game = on_game
          end

          def run
            game_number = 0
            total_games = seeds * profiles.size
            configurations = Array.new(seeds) do |seed_index|
              seed = first_seed + seed_index
              Array.new(profiles.size) do |rotation|
                seat_profiles = profiles.rotate(rotation)
                game_configuration(seed, rotation, seat_profiles)
              end
            end.flatten
            games = configurations.map do |configuration|
              summary = run_games([configuration]).first
              game_number += 1
              on_game&.call(game_number, total_games, summary)
              summary
            end

            TournamentResult.new(
              profiles: profiles,
              seeds: seeds,
              first_seed: first_seed,
              optional_rules: optional_rules,
              games: games,
            )
          end

          private

          def game_configuration(seed, rotation, seat_profiles)
            {
              seed: seed,
              rotation: rotation,
              profiles: seat_profiles.map(&:to_h),
              optional_rules: optional_rules,
              max_actions: max_actions,
            }
          end

          def run_games(configurations)
            configurations.map do |configuration|
              result = run_games_in_new_process([configuration]).first
              next result if result[:status] == 'finished'

              run_games_in_new_process([configuration]).first
            end
          end

          def run_games_in_new_process(configurations)
            input = JSON.generate(configurations)
            output, error, status = Open3.capture3(
              RbConfig.ruby,
              '-Ilib',
              '-e',
              WORKER_SCRIPT,
              stdin_data: input,
              chdir: File.expand_path('../../../../..', __dir__),
            )
            return configurations.map { |configuration| worker_failure(configuration, error, status) } unless status.success?

            JSON.parse(output, symbolize_names: true)
          end

          def worker_failure(configuration, error, status)
            detail = error.lines.find { |line| !line.strip.empty? }&.strip
            detail ||= status.signaled? ? "Worker terminated by signal #{status.termsig}" : "Worker exited #{status.exitstatus}"
            {
              seed: configuration[:seed],
              rotation: configuration[:rotation] + 1,
              status: 'error',
              detail: detail,
              actions_taken: 0,
              seats: configuration[:profiles].map.with_index do |profile, index|
                { seat: index + 1, profile: profile[:name] }
              end,
              results: [],
              last_action: nil,
              backtrace: error.lines.first(20).map(&:strip),
            }
          end
        end
      end
    end
  end
end
