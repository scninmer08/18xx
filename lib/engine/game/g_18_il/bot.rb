# frozen_string_literal: true

require_relative 'game'
require_relative 'bot/baseline_policy'
require_relative 'bot/policy_roster'
require_relative 'bot/runner'
require_relative 'bot/batch_runner'
require_relative 'bot/replay_reporter'
require_relative 'bot/hotseat_exporter'
require_relative 'bot/tournament_runner'
require_relative 'bot/evolution_runner'
require_relative 'bot/report_paths'

module Engine
  module Game
    module G18IL
      module Bot
        def self.run(players: 4, optional_rules: [], seed: 1, max_actions: 1_000, policy: nil, profiles: nil,
                     verbose: false, output: $stdout, log_path: nil, hotseat_path: nil, replay_dir: nil)
          raise ArgumentError, 'Specify policy or profiles, not both' if policy && profiles
          raise ArgumentError, 'Specify hotseat_path or replay_dir, not both' if hotseat_path && replay_dir

          if profiles
            raise ArgumentError, 'Profile count must match player count' unless profiles.size == players

            policy = PolicyRoster.new(profiles)
          end
          policy ||= PolicyRoster.new(PolicyProfile.default_roster(players))

          log_file = File.open(log_path, 'w') if log_path
          outputs = [output, log_file].compact
          outputs.each { |stream| stream.sync = true if stream.respond_to?(:sync=) }
          outputs.each { |stream| stream.puts("Starting 18IL bot replay, seed #{seed}") } if hotseat_path || replay_dir
          names = Array.new(players) { |index| "Bot #{index + 1}" }
          game = ::Engine::Game::G18IL::Game.new(names, seed: seed, optional_rules: optional_rules)
          formatter = Runner.method(:format_trace_entry)
          on_action = ->(entry) { outputs.each { |stream| stream.puts(formatter.call(entry)) } } if verbose
          result = Runner.new(game, policy: policy, max_actions: max_actions, on_action: on_action).run
          replay_requested = hotseat_path || replay_dir
          if replay_requested && result.status == :finished
            hotseat_path ||= ReportPaths.resolve_replay(replay_dir)
            HotseatExporter.new(result).write(hotseat_path)
          elsif replay_requested
            outputs.each do |stream|
              stream.puts("Replay not written: bot run #{result.status}: #{result.detail} " \
                          "(#{result.actions_taken} actions)")
            end
          end
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
                           policy_factory: nil, output: $stdout, verbose: true,
                           text_path: nil, json_path: nil, report_dir: nil)
          text_path, json_path = ReportPaths.resolve(
            report_dir: report_dir,
            prefix: 'batch',
            text_path: text_path,
            json_path: json_path,
          )
          crash_log_dir = batch_crash_log_dir(text_path, json_path)
          game_json_dir = batch_game_json_dir(text_path, json_path)
          progress = if verbose && output
                       lambda do |number, total, summary|
                         elapsed = summary[:elapsed_seconds] ? ", #{format_elapsed(summary[:elapsed_seconds])}" : ''
                         player_count = summary[:player_count] ? ", #{summary[:player_count]}p" : ''
                         output.puts("Game #{number}/#{total}#{player_count}, seed #{summary[:seed]}: " \
                                     "#{summary[:status]} (#{summary[:actions_taken]} actions#{elapsed})")
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
            crash_log_dir: crash_log_dir,
            game_json_dir: game_json_dir,
          ).run

          report = result.format
          output&.puts(report)
          File.write(text_path, "#{report}\n") if text_path
          File.write(json_path, JSON.pretty_generate(result.to_h)) if json_path
          if text_path && json_path
            output&.puts("Reports written to #{text_path} and #{json_path}")
            output&.puts("Game JSONs written to #{game_json_dir}") if game_json_dir && Dir.exist?(game_json_dir)
            output&.puts("Child error logs written to #{crash_log_dir}") if crash_log_dir
          end
          result
        end

        def self.batch_crash_log_dir(text_path, json_path)
          path = text_path || json_path
          return unless path

          path.sub(/\.(?:txt|json)\z/, '_crashes')
        end

        def self.batch_game_json_dir(text_path, json_path)
          path = text_path || json_path
          return unless path

          path.sub(/\.(?:txt|json)\z/, '')
        end

        def self.format_elapsed(seconds)
          seconds = seconds.to_f
          return "in #{format('%.1fs', seconds)}" if seconds < 60

          minutes = (seconds / 60).floor
          remaining_seconds = (seconds % 60).round
          return "in #{minutes}m #{remaining_seconds}s" if minutes < 60

          hours = minutes / 60
          remaining_minutes = minutes % 60
          "in #{hours}h #{remaining_minutes}m"
        end

        def self.report_replay(path = 'test18', output: $stdout, text_path: nil, json_path: nil, at_action: nil)
          report = ReplayReporter.new(path, at_action: at_action).run
          text = report.format
          output&.puts(text)
          File.write(text_path, "#{text}\n") if text_path
          File.write(json_path, JSON.pretty_generate(report.to_h)) if json_path
          report
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
