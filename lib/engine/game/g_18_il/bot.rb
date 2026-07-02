# frozen_string_literal: true

require_relative 'bot/baseline_policy'
require_relative 'bot/policy_roster'
require_relative 'bot/runner'
require_relative 'bot/batch_runner'
require_relative 'bot/hotseat_exporter'
require_relative 'bot/tournament_runner'
require_relative 'bot/evolution_runner'
require_relative 'bot/report_paths'

module Engine
  module Game
    module G18IL
      module Bot
        def self.run(players: 4, optional_rules: [], seed: 1, max_actions: 1_000, policy: nil, profiles: nil,
                     verbose: false, output: $stdout, log_path: nil, hotseat_path: nil)
          raise ArgumentError, 'Specify policy or profiles, not both' if policy && profiles

          if profiles
            raise ArgumentError, 'Profile count must match player count' unless profiles.size == players

            policy = PolicyRoster.new(profiles)
          end
          policy ||= BaselinePolicy.new

          log_file = File.open(log_path, 'w') if log_path
          outputs = [output, log_file].compact
          outputs.each { |stream| stream.sync = true if stream.respond_to?(:sync=) }
          names = Array.new(players) { |index| "Bot #{index + 1}" }
          game = Game.new(names, seed: seed, optional_rules: optional_rules)
          formatter = Runner.method(:format_trace_entry)
          on_action = ->(entry) { outputs.each { |stream| stream.puts(formatter.call(entry)) } } if verbose
          result = Runner.new(game, policy: policy, max_actions: max_actions, on_action: on_action).run
          HotseatExporter.new(result).write(hotseat_path) if hotseat_path
          if verbose
            outputs.each do |stream|
              stream.puts("Bot run #{result.status}: #{result.detail} (#{result.actions_taken} actions)")
            end
          end

          result
        ensure
          log_file&.close
        end

        def self.run_batch(games: 10, players: 4, optional_rules: [], first_seed: 1, max_actions: 2_000,
                           policy_factory: -> { BaselinePolicy.new }, output: $stdout, verbose: true,
                           text_path: nil, json_path: nil, report_dir: nil)
          text_path, json_path = ReportPaths.resolve(
            report_dir: report_dir,
            prefix: 'batch',
            text_path: text_path,
            json_path: json_path,
          )
          progress = if verbose && output
                       lambda do |number, total, summary|
                         output.puts("Game #{number}/#{total}, seed #{summary[:seed]}: " \
                                     "#{summary[:status]} (#{summary[:actions_taken]} actions)")
                         output.flush
                       end
                     end
          result = BatchRunner.new(
            games: games,
            players: players,
            optional_rules: optional_rules,
            first_seed: first_seed,
            max_actions: max_actions,
            policy_factory: policy_factory,
            on_game: progress,
          ).run

          report = result.format
          output&.puts(report)
          File.write(text_path, "#{report}\n") if text_path
          File.write(json_path, JSON.pretty_generate(result.to_h)) if json_path
          output&.puts("Reports written to #{text_path} and #{json_path}") if text_path && json_path
          result
        end

        def self.run_tournament(profiles: PolicyProfile.starter_set, seeds: 2, first_seed: 1, optional_rules: [],
                                max_actions: 2_000, output: $stdout, verbose: true, text_path: nil, json_path: nil,
                                report_dir: nil)
          text_path, json_path = ReportPaths.resolve(
            report_dir: report_dir,
            prefix: 'tournament',
            text_path: text_path,
            json_path: json_path,
          )
          total_games = seeds * profiles.size
          progress = if verbose && output
                       lambda do |number, _total, summary|
                         output.puts("Game #{number}/#{total_games}, seed #{summary[:seed]}, " \
                                     "rotation #{summary[:rotation]}: #{summary[:status]}")
                         output.flush
                       end
                     end
          result = TournamentRunner.new(
            profiles: profiles,
            seeds: seeds,
            first_seed: first_seed,
            optional_rules: optional_rules,
            max_actions: max_actions,
            on_game: progress,
          ).run

          report = result.format
          output&.puts(report)
          File.write(text_path, "#{report}\n") if text_path
          File.write(json_path, JSON.pretty_generate(result.to_h)) if json_path
          output&.puts("Reports written to #{text_path} and #{json_path}") if text_path && json_path
          result
        end

        def self.evolve(initial_profile: PolicyProfile.new, generations: 2, mutations: 3, training_seeds: 1,
                        holdout_seeds: 1, first_seed: 1, holdout_first_seed: nil, optional_rules: [],
                        max_actions: 2_000, magnitude: 0.2, output: $stdout, verbose: true,
                        text_path: nil, json_path: nil, report_dir: nil)
          text_path, json_path = ReportPaths.resolve(
            report_dir: report_dir,
            prefix: 'evolution',
            text_path: text_path,
            json_path: json_path,
          )
          progress = if verbose && output
                       lambda do |stage, number, total, summary|
                         output.puts("#{stage.capitalize}: game #{number}/#{total}, seed #{summary[:seed]}, " \
                                     "rotation #{summary[:rotation]}: #{summary[:status]}")
                         output.flush
                       end
                     end
          result = EvolutionRunner.new(
            initial_profile: initial_profile,
            generations: generations,
            mutations: mutations,
            training_seeds: training_seeds,
            holdout_seeds: holdout_seeds,
            first_seed: first_seed,
            holdout_first_seed: holdout_first_seed,
            optional_rules: optional_rules,
            max_actions: max_actions,
            magnitude: magnitude,
            on_game: progress,
          ).run

          report = result.format
          output&.puts(report)
          File.write(text_path, "#{report}\n") if text_path
          File.write(json_path, JSON.pretty_generate(result.to_h)) if json_path
          output&.puts("Reports written to #{text_path} and #{json_path}") if text_path && json_path
          result
        end
      end
    end
  end
end
