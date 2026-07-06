# frozen_string_literal: true

require 'json'
require 'fileutils' unless RUBY_ENGINE == 'opal'

module Engine
  module Game
    module G18IL
      module Bot
        TRACK_TILE_USAGE_IDS = %w[7 8 9].freeze

        class BatchResult
          attr_reader :games_requested, :players, :optional_rules, :first_seed, :summaries

          def initialize(games_requested:, players:, optional_rules:, first_seed:, summaries:)
            @games_requested = games_requested
            @players = players
            @optional_rules = optional_rules
            @first_seed = first_seed
            @summaries = summaries
          end

          def to_h
            {
              config: {
                games: games_requested,
                players: players,
                optional_rules: optional_rules,
                first_seed: first_seed,
              },
              aggregate: aggregate,
              games: summaries,
            }
          end

          def to_json(*args)
            to_h.to_json(*args)
          end

          def format
            lines = [
              '18IL Bot Batch Report',
              "Games: #{games_requested} | Players: #{players} | Seeds: #{first_seed}-#{first_seed + games_requested - 1}",
              "Rules: #{optional_rules.empty? ? 'regular game' : optional_rules.join(', ')}",
              "Status: #{format_status_counts}",
              "Average actions: #{aggregate[:average_actions]}",
              '',
              'Seat results:',
            ]
            aggregate[:seats].each do |seat|
              lines << "  #{seat[:name]}: #{seat[:wins]} wins, average value #{seat[:average_value]}"
            end
            lines.concat([
                           '',
                           'Seat diagnostics:',
                           '  Opening corporations by seat:',
                         ])
            aggregate[:opening_corporations_by_seat].each do |seat, corporations|
              lines << "    Seat #{seat}: #{format_mix(corporations)}"
            end
            lines.concat([
                           "  IC first presidency by seat: #{format_mix(aggregate[:ic_presidency_by_seat][:first])}",
                           "  IC final presidency by seat: #{format_mix(aggregate[:ic_presidency_by_seat][:final])}",
                           "  IC ever presidency by seat: #{format_mix(aggregate[:ic_presidency_by_seat][:ever])}",
                           '  Winner opening combinations:',
                         ])
            aggregate[:winner_opening_combinations].each do |combo, data|
              lines << "    #{combo}: #{data[:wins]} wins, average winner value #{data[:average_value]}"
            end
            lines.concat([
                           '',
                           'Decision totals:',
                           "  Auction bids: #{aggregate[:metrics][:auction_bids]}",
                           "  Corporations started: #{aggregate[:metrics][:corporations_started]}",
                           "  Conversions: #{aggregate[:metrics][:conversions]}",
                           "  Share purchases: #{aggregate[:metrics][:share_purchases]}",
                           "  Player share sales: #{aggregate[:metrics][:player_share_sales]}",
                           "  Private acquisitions: #{aggregate[:metrics][:private_acquisitions]}",
                           "  Train purchases: #{aggregate[:metrics][:train_purchases]}",
                           "  Trains borrowed: #{aggregate[:metrics][:trains_borrowed]}",
                           "  Trains discarded: #{aggregate[:metrics][:trains_discarded]}",
                           "  Track lays: #{aggregate[:metrics][:track_lays]}",
                           "  Token placements: #{aggregate[:metrics][:token_placements]}",
                           "  Private ability uses: #{aggregate[:metrics][:private_ability_uses]}",
                           "  Routes run: #{aggregate[:metrics][:routes_run]}",
                           "  Route revenue: #{aggregate[:metrics][:route_revenue]}",
                           '',
                           "Par values: #{format_par_mix}",
                           "Train purchases by type: #{format_train_mix}",
                           '',
                           'Game balance:',
                           "  Average corporations opened per game: #{aggregate[:average_corporations_opened]}",
                           "  Average corporations opened per player: #{aggregate[:average_corporations_per_player]}",
                           "  Peak track tile usage: #{format_track_tile_usage}",
                           "  Train lifecycle: #{format_train_lifecycle}",
                           "  Train route revenue: #{format_train_performance}",
                           "  Winner dividend receipts by train: #{format_winner_train_payouts}",
                           "  Games where winner held each presidency: #{format_winner_presidencies}",
                           '',
                           'Par prices by corporation:',
                         ])
            aggregate[:par_by_corporation].sort.each do |corporation, prices|
              lines << "  #{corporation}: #{format_mix(prices)}"
            end
            failures = summaries.reject { |summary| summary[:status] == 'finished' }
            unless failures.empty?
              lines << ''
              lines << 'Incomplete games:'
              failures.each do |summary|
                lines << "  Seed #{summary[:seed]}: #{summary[:status]} - #{summary[:detail]}"
                last_action = summary.dig(:failure, :last_action)
                lines << "    Last action: #{format_last_action(last_action)}" if last_action
                Array(summary.dig(:failure, :crash_logs)).each do |path|
                  lines << "    Error log: #{path}"
                end
              end
            end
            recovered = summaries.select { |summary| summary[:status] == 'finished' && summary.dig(:failure, :crash_logs)&.any? }
            unless recovered.empty?
              lines << ''
              lines << 'Recovered child error logs:'
              recovered.each do |summary|
                lines << "  Seed #{summary[:seed]} finished after a failed child attempt"
                Array(summary.dig(:failure, :crash_logs)).each do |path|
                  lines << "    Error log: #{path}"
                end
              end
            end
            lines.join("\n")
          end

          def aggregate
            @aggregate ||= {
              status_counts: summaries.group_by { |summary| summary[:status] }.transform_values(&:size),
              average_actions: average(summaries.map { |summary| summary[:actions_taken] }),
              seats: seat_results,
              metrics: metric_totals,
              par_mix: par_mix,
              train_mix: train_mix,
              average_corporations_opened: average(summaries.map { |summary| summary[:par_events].size }),
              average_corporations_per_player: average(
                summaries.flat_map { |summary| summary[:players].map { |player| openings_for(summary, player[:name]) } },
              ),
              par_by_corporation: par_by_corporation,
              track_tile_usage: track_tile_usage,
              train_lifecycle: train_lifecycle,
              train_performance: train_performance,
              winner_train_payouts: winner_train_payouts,
              winner_presidencies: winner_presidencies,
              opening_corporations_by_seat: opening_corporations_by_seat,
              ic_presidency_by_seat: ic_presidency_by_seat,
              winner_opening_combinations: winner_opening_combinations,
            }
          end

          private

          def format_status_counts
            aggregate[:status_counts].sort.map { |status, count| "#{status}=#{count}" }.join(', ')
          end

          def format_train_mix
            aggregate[:train_mix].sort.map { |train, count| "#{train}=#{count}" }.join(', ')
          end

          def format_par_mix
            aggregate[:par_mix].sort.map { |price, count| "#{price}=#{count}" }.join(', ')
          end

          def format_mix(mix)
            mix.sort_by { |key, _count| key.to_s }.map { |key, count| "#{key}=#{count}" }.join(', ')
          end

          def format_train_lifecycle
            aggregate[:train_lifecycle].sort.map do |train, counts|
              "#{train} bought=#{counts[:purchased]} exported=#{counts[:exported]}"
            end.join('; ')
          end

          def format_train_performance
            aggregate[:train_performance].sort.map do |train, data|
              "#{train} runs=#{data[:runs]} avg=#{data[:average_revenue]}"
            end.join('; ')
          end

          def format_winner_train_payouts
            aggregate[:winner_train_payouts].sort.map do |train, data|
              "#{train}=#{data[:amount]} (#{data[:payouts]} payouts)"
            end.join(', ')
          end

          def format_winner_presidencies
            format_mix(aggregate[:winner_presidencies])
          end

          def format_track_tile_usage
            aggregate[:track_tile_usage].map do |tile, data|
              "##{tile} avg=#{data[:average]} max=#{data[:max]}"
            end.join(', ')
          end

          def seat_results
            (1..players).map do |seat|
              results = completed_summaries.filter_map { |summary| summary[:players].find { |player| player[:seat] == seat } }
              {
                seat: seat,
                name: "Bot #{seat}",
                wins: results.count { |result| result[:rank] == 1 },
                average_value: average(results.map { |result| result[:value] }),
              }
            end
          end

          def completed_summaries
            summaries.select { |summary| summary[:status] == 'finished' }
          end

          def metric_totals
            summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary[:metrics].each { |metric, value| totals[metric] += value }
            end.to_h
          end

          def train_mix
            summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary[:train_mix].each { |train, count| totals[train] += count }
            end.to_h
          end

          def par_mix
            summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary[:par_mix].each { |price, count| totals[price] += count }
            end.to_h
          end

          def openings_for(summary, player_name)
            summary[:par_events].count { |event| event[:player] == player_name }
          end

          def par_by_corporation
            summaries.flat_map { |summary| summary[:par_events] }.each_with_object({}) do |event, totals|
              totals[event[:corporation]] ||= Hash.new(0)
              totals[event[:corporation]][event[:price]] += 1
            end.transform_values(&:to_h)
          end

          def track_tile_usage
            TRACK_TILE_USAGE_IDS.to_h do |tile|
              counts = summaries.map { |summary| summary.fetch(:track_tile_usage, {}).fetch(tile, 0) }
              [tile, { average: average(counts), max: counts.max || 0 }]
            end
          end

          def train_lifecycle
            summaries.flat_map { |summary| summary[:train_events] }.each_with_object({}) do |event, totals|
              totals[event[:train]] ||= { purchased: 0, exported: 0 }
              totals[event[:train]][event[:event].to_sym] += 1
            end
          end

          def train_performance
            runs = summaries.flat_map { |summary| summary[:train_runs] }
            runs.group_by { |run| run[:train] }.to_h do |train, train_runs|
              revenues = train_runs.map { |run| run[:revenue] }
              [train, { runs: train_runs.size, total_revenue: revenues.sum, average_revenue: average(revenues) }]
            end
          end

          def winner_train_payouts
            totals = Hash.new { |hash, train| hash[train] = { amount: 0.0, payouts: 0 } }
            summaries.each do |summary|
              winner = summary[:players].find { |player| player[:rank] == 1 }
              next unless winner

              summary[:dividends].each do |dividend|
                amount = dividend[:player_payouts][winner[:name]].to_f
                route_total = dividend[:routes].sum { |route| route[:revenue] }
                next if amount.zero? || route_total.zero?

                dividend[:routes].each do |route|
                  data = totals[route[:train]]
                  data[:amount] += amount * route[:revenue] / route_total
                  data[:payouts] += 1
                end
              end
            end
            totals.transform_values { |data| data.merge(amount: data[:amount].round(1)) }
          end

          def winner_presidencies
            completed_summaries.each_with_object(Hash.new(0)) do |summary, totals|
              winner = summary[:players].find { |player| player[:rank] == 1 }
              next unless winner

              summary[:presidency_events]
                .select { |event| event[:player] == winner[:name] }
                .map { |event| event[:corporation] }
                .uniq
                .each { |corporation| totals[corporation] += 1 }
            end.to_h
          end

          def opening_corporations_by_seat
            totals = (1..players).to_h { |seat| [seat, Hash.new(0)] }
            completed_summaries.each do |summary|
              seats = player_seats(summary)
              summary[:par_events].each do |event|
                seat = seats[event[:player]]
                totals[seat][event[:corporation]] += 1 if seat
              end
            end
            totals.transform_values(&:to_h)
          end

          def ic_presidency_by_seat
            counts = {
              first: Hash.new(0),
              final: Hash.new(0),
              ever: Hash.new(0),
            }
            completed_summaries.each do |summary|
              seats = player_seats(summary)
              ic_events = summary[:presidency_events].select { |event| event[:corporation] == 'IC' }

              first_seat = seats[ic_events.first&.dig(:player)]
              counts[:first][first_seat || 'none'] += 1

              final_owner = summary[:corporations].find { |corporation| corporation[:name] == 'IC' }&.dig(:owner)
              final_seat = seats[final_owner]
              counts[:final][final_seat || 'none'] += 1

              ic_events.map { |event| seats[event[:player]] }.compact.uniq.each do |seat|
                counts[:ever][seat] += 1
              end
              counts[:ever]['none'] += 1 if ic_events.empty?
            end
            counts.transform_values(&:to_h)
          end

          def winner_opening_combinations
            grouped = completed_summaries.group_by do |summary|
              winner = summary[:players].find { |player| player[:rank] == 1 }
              opened = summary[:par_events]
                .select { |event| event[:player] == winner&.dig(:name) }
                .map { |event| event[:corporation] }
                .sort
              opened.empty? ? 'none' : opened.join('+')
            end
            grouped.to_h do |combo, combo_summaries|
              values = combo_summaries.filter_map do |summary|
                summary[:players].find { |player| player[:rank] == 1 }&.dig(:value)
              end
              [combo, { wins: combo_summaries.size, average_value: average(values) }]
            end.sort_by { |combo, data| [-data[:wins], combo] }.to_h
          end

          def player_seats(summary)
            summary[:players].to_h { |player| [player[:name], player[:seat]] }
          end

          def average(values)
            return 0 if values.empty?

            (values.sum.to_f / values.size).round(1)
          end

          def format_last_action(action)
            "T#{action[:turn]} #{action[:round]} | #{action[:entity]} | #{action[:step]} | #{action[:action]}"
          end
        end

        class BatchRunner
          attr_reader :games, :players, :optional_rules, :first_seed, :max_actions, :policy_factory, :on_game,
                      :crash_log_dir

          def initialize(games:, players:, optional_rules:, first_seed:, max_actions:, policy_factory:, on_game: nil,
                         crash_log_dir: nil)
            raise ArgumentError, 'games must be positive' unless games.positive?

            @games = games
            @players = players
            @optional_rules = optional_rules
            @first_seed = first_seed
            @max_actions = max_actions
            @policy_factory = policy_factory
            @on_game = on_game
            @crash_log_dir = crash_log_dir
          end

          def run
            summaries = Array.new(games) do |index|
              seed = first_seed + index
              summary = run_game(seed)
              on_game&.call(index + 1, games, summary)
              summary
            end

            BatchResult.new(
              games_requested: games,
              players: players,
              optional_rules: optional_rules,
              first_seed: first_seed,
              summaries: summaries,
            )
          end

          private

          def run_game(seed)
            return run_game_in_process(seed) unless Process.respond_to?(:fork)

            summary = run_game_in_child(seed, 1)
            return attach_seed_crash_logs(summary, seed) if summary&.dig(:status) == 'finished'

            summary = run_game_in_child(seed, 2)
            return attach_seed_crash_logs(summary, seed) if summary

            crashed_worker_summary(seed)
          end

          def run_game_in_process(seed)
            summarize(run_bot(seed), seed)
          rescue StandardError => e
            worker_error_summary(seed, e)
          end

          def run_game_in_child(seed, attempt)
            log_path = crash_log_path(seed, attempt)
            reader, writer = IO.pipe
            pid = Process.fork do
              reader.close
              redirect_child_error_log(log_path)
              payload = run_game_in_process(seed)
              Marshal.dump(payload, writer)
              writer.close
              exit! 0
            end
            writer.close
            payload = Marshal.load(reader)
            reader.close
            _waited_pid, status = Process.waitpid2(pid)
            status.success? ? attach_crash_log(payload, log_path) : nil
          rescue EOFError, TypeError
            Process.waitpid(pid) if pid
            nil
          rescue Errno::ECHILD
            nil
          ensure
            reader&.close unless reader&.closed?
            writer&.close unless writer&.closed?
          end

          def crash_log_path(seed, attempt)
            return unless crash_log_dir

            FileUtils.mkdir_p(crash_log_dir)
            File.join(crash_log_dir, format('seed_%<seed>s_attempt_%<attempt>d.log', seed: seed, attempt: attempt))
          end

          def redirect_child_error_log(path)
            return unless path

            file = File.open(path, 'w')
            file.sync = true
            STDERR.reopen(file)
            STDERR.sync = true
          end

          def attach_crash_log(summary, path)
            return summary unless path && File.size?(path)

            summary[:failure] ||= {}
            summary[:failure][:crash_logs] = (Array(summary.dig(:failure, :crash_logs)) + [path]).uniq
            summary
          end

          def attach_seed_crash_logs(summary, seed)
            logs = seed_crash_logs(seed)
            return summary if logs.empty?

            summary[:failure] ||= {}
            summary[:failure][:crash_logs] = (Array(summary.dig(:failure, :crash_logs)) + logs).uniq
            summary
          end

          def seed_crash_logs(seed)
            return [] unless crash_log_dir

            Dir[File.join(crash_log_dir, "seed_#{seed}_attempt_*.log")]
              .select { |path| File.size?(path) }
              .sort
          end

          def run_bot(seed)
            policy =
              if policy_factory
                policy_factory.arity.zero? ? policy_factory.call : policy_factory.call(seed)
              end
            Bot.run(
              players: players,
              optional_rules: optional_rules,
              seed: seed,
              max_actions: max_actions,
              policy: policy,
            )
          end

          def crashed_worker_summary(seed)
            {
              seed: seed,
              status: 'error',
              detail: 'Game worker crashed twice',
              actions_taken: 0,
              turn: nil,
              players: [],
              corporations: [],
              presidency_events: [],
              par_events: [],
              train_events: [],
              train_runs: [],
              dividends: [],
              metrics: {},
              par_mix: {},
              train_mix: {},
              track_tile_usage: {},
              failure: { exception_class: 'WorkerCrash', crash_logs: seed_crash_logs(seed) },
            }
          end

          def worker_error_summary(seed, exception)
            crashed_worker_summary(seed).merge(
              detail: "#{exception.class}: #{exception.message}",
              failure: { exception_class: exception.class.name, backtrace: exception.backtrace&.first(20) },
            )
          end

          def summarize(result, seed)
            game = result.game
            rankings = game.result.keys.each_with_index.to_h { |player_id, index| [player_id, index + 1] }
            {
              seed: seed,
              status: result.status.to_s,
              detail: result.detail,
              actions_taken: result.actions_taken,
              turn: game.turn,
              players: summarize_players(game, rankings),
              corporations: summarize_corporations(game),
              presidency_events: result.events.to_a.select { |entry| entry[:event] == 'presidency' },
              par_events: summarize_par_events(result.trace),
              train_events: summarize_train_events(result),
              train_runs: summarize_train_runs(result.trace),
              dividends: result.trace.select { |entry| entry[:action] == 'dividend' }.map do |entry|
                entry.slice(:corporation, :president, :kind, :revenue, :corporation_withheld, :player_payouts, :routes)
              end,
              metrics: summarize_metrics(result.trace),
              par_mix: result.trace
                .select { |entry| entry[:action] == 'par' }
                .group_by { |entry| entry[:price] }
                .transform_values(&:size),
              train_mix: result.trace
                .select { |entry| entry[:action] == 'buy_train' }
                .group_by { |entry| entry[:train] }
                .transform_values(&:size),
              track_tile_usage: summarize_track_tile_usage(result.trace),
              failure: summarize_failure(result),
            }
          end

          def summarize_failure(result)
            return if result.status == :finished

            game = result.game
            step = game.round&.active_step
            entity = game.round&.current_entity
            exception = game.exception
            {
              round: game.round&.name,
              step: step&.description,
              entity: entity&.name,
              available_actions: entity && step ? step.actions(entity) : [],
              last_action: result.trace.last,
              exception_class: exception&.class&.name,
              backtrace: exception&.backtrace&.first(20),
            }
          rescue StandardError => e
            { diagnostic_error: "#{e.class}: #{e.message}", last_action: result.trace.last }
          end

          def summarize_par_events(trace)
            trace.select { |entry| entry[:action] == 'par' }.map do |entry|
              { corporation: entry[:corporation], price: entry[:price], player: entry[:entity], turn: entry[:turn] }
            end
          end

          def summarize_train_events(result)
            purchases = result.trace.select { |entry| entry[:action] == 'buy_train' }.map do |entry|
              {
                event: 'purchased', train: entry[:train], corporation: entry[:corporation],
                price: entry[:price], turn: entry[:turn],
              }
            end
            exports = result.events.to_a.select { |entry| entry[:event] == 'train_export' }.map do |entry|
              { event: 'exported', train: entry[:train], turn: entry[:turn], round: entry[:round] }
            end
            purchases + exports
          end

          def summarize_train_runs(trace)
            trace.select { |entry| entry[:action] == 'run_routes' }.flat_map do |entry|
              entry[:routes].map do |route|
                route.merge(
                  corporation: entry[:corporation], president: entry[:president], turn: entry[:turn], round: entry[:round]
                )
              end
            end
          end

          def summarize_players(game, rankings)
            game.players.map.with_index do |player, index|
              {
                seat: player.id.to_s[/\d+\z/].to_i.nonzero? || index + 1,
                name: player.name,
                rank: rankings[player.id],
                value: game.player_value(player),
                cash: player.cash,
                share_value: player.shares.select { |share| share.corporation.ipoed }.sum(&:price),
                presidencies: game.corporations.select { |corporation| corporation.owner == player }.map(&:name).sort,
                privates: player.companies.select { |company| company.meta[:type] == :private }.map(&:name).sort,
              }
            end
          end

          def summarize_corporations(game)
            game.corporations.sort_by(&:name).map do |corporation|
              {
                name: corporation.name,
                open: corporation.ipoed,
                owner: corporation.owner&.name,
                share_price: corporation.share_price&.price,
                cash: corporation.cash,
                trains: corporation.trains.map(&:name),
                privates: corporation.companies
                  .select { |company| company.meta[:type] == :private }
                  .map(&:name)
                  .sort,
              }
            end
          end

          def summarize_metrics(trace)
            {
              auction_bids: trace.count do |entry|
                entry[:action] == 'bid' && entry[:reason].start_with?('Bids', 'Opens bidding')
              end,
              corporations_started: trace.count { |entry| entry[:action] == 'par' },
              conversions: trace.count { |entry| entry[:action] == 'convert' },
              share_purchases: trace.count { |entry| entry[:action] == 'buy_shares' },
              player_share_sales: trace.count do |entry|
                entry[:action] == 'sell_shares' && entry[:entity_type] == 'player'
              end,
              private_acquisitions: trace.count { |entry| entry[:action] == 'acquire_company' },
              train_purchases: trace.count { |entry| entry[:action] == 'buy_train' },
              trains_borrowed: trace.count { |entry| entry[:action] == 'borrow_train' },
              trains_discarded: trace.count { |entry| entry[:action] == 'discard_train' },
              track_lays: trace.count { |entry| entry[:action] == 'lay_tile' },
              token_placements: trace.count { |entry| entry[:action] == 'place_token' },
              private_ability_uses: trace.count do |entry|
                entry[:entity_type] == 'company' || entry[:reason].start_with?('Uses Planned Obsolescence')
              end,
              routes_run: trace.count { |entry| entry[:action] == 'run_routes' },
              route_revenue: trace.sum { |entry| entry[:route_revenue].to_i + entry[:subsidy].to_i },
            }
          end

          def summarize_track_tile_usage(trace)
            tiles_by_hex = {}
            current = Hash.new(0)
            peak = TRACK_TILE_USAGE_IDS.to_h { |tile| [tile, 0] }

            trace.each do |entry|
              next unless entry[:action] == 'lay_tile'

              hex = entry[:hex]
              old_tile = tiles_by_hex[hex]
              current[old_tile] -= 1 if peak.key?(old_tile)

              new_tile = normalized_tile_id(entry[:tile])
              tiles_by_hex[hex] = new_tile
              next unless peak.key?(new_tile)

              current[new_tile] += 1
              peak[new_tile] = [peak[new_tile], current[new_tile]].max
            end

            peak
          end

          def normalized_tile_id(tile)
            tile.to_s.split('-', 2).first
          end
        end
      end
    end
  end
end
