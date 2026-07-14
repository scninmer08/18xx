# frozen_string_literal: true

# rubocop:disable Style/GlobalVars

if RUBY_ENGINE != 'opal' && File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__) &&
   !$g18_il_replay_reporter_loading
  $g18_il_replay_reporter_loading = true

  require 'engine/logger'

  Engine::Logger.set_level(Logger::FATAL)
  require 'require_all'
  require_all 'lib/engine/game/g_18_il'

  exit Engine::Game::G18IL::Bot::ReplayReporter::CLI.run(ARGV)
end

# rubocop:enable Style/GlobalVars

require 'json'

module Engine
  module Game
    module G18IL
      module Bot
        ReplayReport = Struct.new(
          :source_path,
          :summary,
          :batch_result,
          :actions_total,
          :actions_replayed,
          keyword_init: true,
        ) do
          def to_h
            {
              source_path: source_path,
              actions_total: actions_total,
              actions_replayed: actions_replayed,
              summary: summary,
              aggregate: batch_result.aggregate,
            }
          end

          def format
            lines = [
              '18IL Replay Report',
              "File: #{display_path(source_path)}",
              "Status: #{summary[:status]} - #{summary[:detail]}",
              "Seed: #{summary[:seed]} | Players: #{summary[:players].size} | Source actions: #{actions_total} | " \
              "Active replayed: #{actions_replayed}",
              "Turn: #{summary[:turn]} | Round: #{summary[:round]} | " \
              "Source status: #{summary[:source_status] || 'unknown'}",
              '',
              'Current standings:',
            ]
            current_standings.each.with_index(1) do |player, index|
              lines << "  #{index}. #{player[:name]}: value $#{player[:value]}, cash $#{player[:cash]}, " \
                       "shares $#{player[:share_value]}, presidencies #{format_list(player[:presidencies])}"
            end

            batch_lines = batch_result.format.split("\n")
            batch_lines[0] = '18IL Bot Batch-Style Stats'
            lines.concat([''], batch_lines)
            lines.join("\n")
          end

          private

          def current_standings
            summary[:players].sort_by { |player| [-player[:value].to_i, player[:seat].to_i] }
          end

          def display_path(path)
            expanded = File.expand_path(path)
            root = "#{Dir.pwd}/"
            expanded.start_with?(root) ? expanded.delete_prefix(root) : expanded
          end

          def format_list(items)
            items.empty? ? 'none' : items.join(', ')
          end
        end

        class ReplayReporter
          DEFAULT_TEST_DIR = File.expand_path('reports/tests', __dir__)

          attr_reader :input, :at_action

          def initialize(input = 'test18', at_action: nil)
            @input = input
            @at_action = at_action
          end

          def run
            path = resolve_path(input)
            data = JSON.parse(File.read(path))
            source_actions = data.fetch('actions')
            replay_actions = action_window(source_actions)
            result = replay(data, replay_actions)
            seed = seed_from(data)
            summary = BatchRunner.summarize_result(result, seed, nil).merge(
              source_path: path,
              source_status: data['status'],
              actions_total: source_actions.size,
              actions_replayed: result.actions_taken,
              round: round_label(result.game),
            )
            batch_result = BatchResult.new(
              games_requested: 1,
              players: result.game.players.size,
              optional_rules: optional_rules_from(data),
              first_seed: seed.to_i,
              summaries: [summary],
            )

            ReplayReport.new(
              source_path: path,
              summary: summary,
              batch_result: batch_result,
              actions_total: source_actions.size,
              actions_replayed: result.actions_taken,
            )
          end

          class CLI
            def self.run(argv, output: $stdout)
              options = {}
              parser = option_parser(options, output)
              parser.parse!(argv)
              input = argv.shift || 'test18'
              raise ArgumentError, "Unexpected arguments: #{argv.join(' ')}" unless argv.empty?

              report = ReplayReporter.new(input, at_action: options[:at_action]).run
              text = report.format
              output.puts(text)
              File.write(options[:text_path], "#{text}\n") if options[:text_path]
              File.write(options[:json_path], JSON.pretty_generate(report.to_h)) if options[:json_path]
              0
            rescue OptionParser::ParseError, ArgumentError, KeyError, JSON::ParserError => e
              output.puts("Replay report failed: #{e.message}")
              output.puts
              output.puts(parser) if parser
              1
            end

            def self.option_parser(options, output)
              require 'optparse'

              OptionParser.new do |parser|
                parser.banner = 'Usage: replay_reporter.rb [test-name-or-path] [options]'
                parser.on('--at-action ID', Integer, 'Replay only through the given action id') do |id|
                  options[:at_action] = id
                end
                parser.on('--text PATH', 'Write the readable report to PATH') do |path|
                  options[:text_path] = path
                end
                parser.on('--json PATH', 'Write the structured report to PATH') do |path|
                  options[:json_path] = path
                end
                parser.on('-h', '--help', 'Show this help') do
                  output.puts(parser)
                  exit 0
                end
              end
            end
          end

          private

          def resolve_path(value)
            raw = value.to_s
            candidates = [raw]
            candidates << "#{raw}.json" if File.extname(raw).empty?
            unless raw.start_with?('/')
              candidates << File.join(DEFAULT_TEST_DIR, raw)
              candidates << File.join(DEFAULT_TEST_DIR, "#{raw}.json") if File.extname(raw).empty?
            end

            path = candidates.map { |candidate| File.expand_path(candidate) }.find { |candidate| File.file?(candidate) }
            return path if path

            raise ArgumentError, "No replay JSON found for #{value.inspect}; tried #{candidates.join(', ')}"
          end

          def action_window(actions)
            return actions unless at_action

            actions.take_while { |action| action.fetch('id', 0).to_i <= at_action }
          end

          def replay(data, actions)
            game = build_game(data)
            filtered_actions, active_undos = game.class.filtered_actions(actions)
            game.instance_variable_set(:@filtered_actions, filtered_actions)
            game.instance_variable_set(:@raw_all_actions, actions)
            game.instance_variable_set(:@redo_possible, active_undos.any?)

            runner = Runner.new(game, policy: nil)
            initialize_runner_observers(runner)
            trace = []
            peak_player_cash = runner.send(:total_player_cash)

            filtered_actions.each do |action_h|
              next unless action_h

              action = Engine::Action::Base.action_from_h(action_h, game)
              decision = Decision.new(action: action, reason: replay_reason(action_h))
              trace_entry = runner.send(:trace_entry, decision)
              trace_entry[:action_id] = action_h['id']
              trace << trace_entry
              runner.send(:observe_train_exports) { game.process_action(action) }
              preserve_action_id(game, action, action_h)
              peak_player_cash = [peak_player_cash, runner.send(:total_player_cash)].max
              break if game.exception || game.finished
            end

            Result.new(
              status: replay_status(game),
              game: game,
              actions_taken: trace.size,
              detail: replay_detail(game, trace.size, actions.size),
              trace: trace,
              events: runner.instance_variable_get(:@events),
              peak_player_cash: peak_player_cash,
              error_backtrace: game.exception&.backtrace,
            )
          end

          def build_game(data)
            ::Engine::Game::G18IL::Game.new(
              player_names(data),
              seed: seed_from(data),
              optional_rules: optional_rules_from(data),
            )
          end

          def player_names(data)
            data.fetch('players').to_h { |player| [player.fetch('id'), player.fetch('name')] }
          end

          def optional_rules_from(data)
            Array(data.dig('settings', 'optional_rules'))
          end

          def seed_from(data)
            data.dig('settings', 'seed') || data['seed'] || data['id'].to_s[/\d+/]
          end

          def initialize_runner_observers(runner)
            runner.instance_variable_set(:@events, [])
            runner.instance_variable_set(:@presidencies, runner.send(:presidency_state))
            runner.instance_variable_set(:@closed_corporations, runner.send(:closed_corporation_state))
            runner.instance_variable_set(:@ic_formation_triggered, runner.game.ic_formation_triggered?)
            runner.instance_variable_set(:@train_origins, {})
          end

          def preserve_action_id(game, action, action_h)
            id = action_h['id']
            return unless id

            action.id = id
            game.raw_actions.last['id'] = id unless game.raw_actions.empty?
            game.instance_variable_set(:@last_processed_action, id)
          end

          def replay_status(game)
            return :error if game.exception
            return :finished if game.finished

            :in_progress
          end

          def replay_detail(game, actions_taken, actions_available)
            return game.exception.message if game.exception
            return 'Game completed' if game.finished
            return "Replay stopped at action #{at_action} after #{actions_taken} actions" if at_action

            "Replay in progress after #{actions_taken} active actions from #{actions_available} source actions"
          end

          def replay_reason(action_h)
            return 'Bids from replay' if action_h.fetch('type') == 'bid'

            "Replay action #{action_h.fetch('type')}"
          end

          def round_label(game)
            round = game.round
            return unless round
            return "OR #{game.turn}.#{round.round_num}" if round.name == 'Operating Round'
            return "SR #{game.turn}" if round.name == 'Stock Round'

            round.name
          end
        end
      end
    end
  end
end
