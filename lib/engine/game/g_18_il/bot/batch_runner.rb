# frozen_string_literal: true

# rubocop:disable Security/MarshalLoad, Style/MultilineBlockChain, Style/UnlessLogicalOperators

require 'json'
require 'fileutils' unless RUBY_ENGINE == 'opal'
require_relative 'hotseat_exporter'

module Engine
  module Game
    module G18IL
      module Bot
        TRACK_TILE_USAGE_IDS = %w[7 8 9 80 81 82 83 544 545 546].freeze
        CITY_HOTSPOT_LIMIT = 15
        ROGERS_TRAIN_NAME = 'Rogers (1+1)'
        TRAIN_REPORT_ORDER = {
          '2' => 0,
          '3' => 1,
          '4' => 2,
          '0+3C' => 3,
          '5' => 4,
          '4+2C' => 5,
          '4+2C + Pullman 4' => 5,
          '5+1C' => 6,
          '5+1C + Pullman 5' => 6,
          '6' => 7,
          '6+1C' => 8,
          '8' => 9,
          '9' => 10,
          'D' => 11,
        }.freeze

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
              "Games: #{games_requested} | Players: #{format_players_config} | Seeds: #{first_seed}-#{first_seed + games_requested - 1}",
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
                           '  Personality usage by seat:',
                         ])
            aggregate[:personality_usage_by_seat].each do |seat, profiles|
              lines << "    Seat #{seat}: #{format_mix(profiles)}"
            end
            lines << '  Personality wins:'
            aggregate[:personality_results].each do |profile, data|
              lines << "    #{profile}: #{data[:wins]} wins / #{data[:appearances]} seats " \
                       "(#{data[:win_rate]}%), average winner value #{data[:average_winner_value]}"
            end
            lines.concat([
                           '  Opening corporations by seat:',
                         ])
            aggregate[:opening_corporations_by_seat].each do |seat, corporations|
              lines << "    Seat #{seat}: #{format_mix(corporations)}"
            end
            lines.concat([
                           "  Opening execution:#{format_opening_execution}",
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
                           'Decision averages:',
                           "  Auction bids: #{aggregate[:metric_averages][:auction_bids]}",
                           "  Corporations started: #{aggregate[:metric_averages][:corporations_started]}",
                           "  Conversions: #{aggregate[:metric_averages][:conversions]}",
                           "  Share purchases: #{aggregate[:metric_averages][:share_purchases]}",
                           "  Player share sales: #{aggregate[:metric_averages][:player_share_sales]}",
                           "  Private acquisitions: #{aggregate[:metric_averages][:private_acquisitions]}",
                           "  Train purchases: #{aggregate[:metric_averages][:train_purchases]}",
                           "  Track lays: #{aggregate[:metric_averages][:track_lays]}",
                           "  Token placements: #{aggregate[:metric_averages][:token_placements]}",
                           "  Private ability uses: #{aggregate[:metric_averages][:private_ability_uses]}",
                           "  Routes run: #{aggregate[:metric_averages][:routes_run]}",
                           "  Route revenue: #{aggregate[:metric_averages][:route_revenue]}",
                           '',
                           "Par values: #{format_par_mix}",
                           "Train purchases by type: #{format_train_mix}",
                           '',
                           'Game balance:',
                           "  Average corporations opened per game: #{aggregate[:average_corporations_opened]}",
                           "  Average corporations opened per player: #{aggregate[:average_corporations_per_player]}",
                           "  Corporation closures: avg=#{aggregate[:average_corporations_closed]} " \
                           "max=#{aggregate[:max_corporations_closed]}",
                           "  Corporation closures by corporation: #{format_closure_mix}",
                           "  Corporation closure diagnostics: #{format_closure_diagnostics}",
                           "  Winner closed a corporation: #{format_winner_closure_games}",
                           "  Peak track tile usage: #{format_track_tile_usage}",
                           "  Peak player cash: #{format_peak_player_cash}",
                           "  Train lifecycle:#{format_train_lifecycle}",
                           "  Train route revenue:#{format_train_performance}",
                         ])
            lines.concat(player_count_trend_report_lines)
            lines.concat([
                           "  Late non-permanent 4 runs: #{format_late_non_permanent_four_runs}",
                           "  City revenue hotspots:#{format_city_hotspots}",
                           "  0+3C city stops: #{format_zero_three_city_stops}",
                           "  Winner dividend receipts by train: #{format_winner_train_payouts}",
                           "  IC total wins: #{aggregate[:ic_winner_count]}",
                           "  IC formation timing: #{format_ic_formation_timing}",
                           "  IC non-formation: #{format_ic_non_formation}",
                           "  IC non-formation games:#{format_ic_non_formation_games}",
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
              metric_averages: metric_averages,
              par_mix: par_mix,
              train_mix: train_mix,
              player_counts: player_count_mix,
              player_count_breakdown: player_count_breakdown,
              average_corporations_opened: average(summaries.map { |summary| summary[:par_events].size }),
              average_corporations_per_player: average_corporations_per_player_for(summaries),
              average_corporations_closed: average(completed_summaries.map { |summary| corporation_closures(summary) }),
              max_corporations_closed: completed_summaries.map { |summary| corporation_closures(summary) }.max || 0,
              closures_by_corporation: closures_by_corporation,
              closure_diagnostics: closure_diagnostics,
              winner_closure_games: winner_closure_games,
              par_by_corporation: par_by_corporation,
              peak_player_cash: peak_player_cash,
              track_tile_usage: track_tile_usage,
              train_lifecycle: train_lifecycle,
              train_performance: train_performance,
              late_non_permanent_four_runs: late_non_permanent_four_runs,
              city_hotspots: city_hotspots,
              zero_three_city_stops: zero_three_city_stops,
              winner_train_payouts: winner_train_payouts,
              winner_presidencies: winner_presidencies,
              ic_winner_count: ic_winner_count,
              ic_formation_timing: ic_formation_timing,
              ic_non_formation: ic_non_formation,
              personality_usage_by_seat: personality_usage_by_seat,
              personality_results: personality_results,
              opening_corporations_by_seat: opening_corporations_by_seat,
              opening_execution: opening_execution,
              ic_presidency_by_seat: ic_presidency_by_seat,
              winner_opening_combinations: winner_opening_combinations,
            }
          end

          private

          def format_status_counts
            aggregate[:status_counts].sort.map { |status, count| "#{status}=#{count}" }.join(', ')
          end

          def format_players_config
            return players unless configured_player_counts.size > 1

            "#{configured_player_counts.join(', ')} mixed"
          end

          def player_count_trend_report_lines
            return [] unless mixed_player_counts?

            lines = ['  Player-count trends:']
            aggregate[:player_count_breakdown].each do |count, data|
              lines << "    #{count}p games=#{data[:games]} avg_actions=#{data[:average_actions]} " \
                "corps/game=#{data[:average_corporations_opened]} corps/player=#{data[:average_corporations_per_player]}"
              lines << "      train rev/$: #{format_train_lifecycle_value_summary(data[:train_lifecycle])}"
              lines << "      train avg route: #{format_train_performance_value_summary(data[:train_performance])}"
            end
            lines
          end

          def format_train_lifecycle_value_summary(lifecycle)
            entries = ordered_train_entries(lifecycle)
            return 'none' if entries.empty?

            entries.map { |train, data| "#{train}=#{data[:revenue_per_price]}" }.join(', ')
          end

          def format_train_performance_value_summary(performance)
            entries = ordered_train_entries(performance)
            return 'none' if entries.empty?

            entries.map { |train, data| "#{train}=#{data[:average_revenue]}" }.join(', ')
          end

          def format_train_mix
            ordered_train_entries(aggregate[:train_mix]).map { |train, count| "#{train}=#{count}" }.join(', ')
          end

          def format_par_mix
            aggregate[:par_mix].sort.map { |price, count| "#{price}=#{count}" }.join(', ')
          end

          def format_closure_mix
            mix = aggregate[:closures_by_corporation]
            return 'none' if mix.empty?

            format_mix(mix)
          end

          def format_closure_diagnostics
            data = aggregate[:closure_diagnostics]
            return 'none' if data[:total].zero?

            "closure_plan=#{data[:planned]}, no_closure_plan=#{data[:unplanned]}, " \
              "with_trains=#{data[:with_trains]}, " \
              "active_operators=#{data[:active_operators]}, permanent=#{data[:with_permanent]}, " \
              "avg_last_route=#{data[:average_last_route_revenue]}; " \
              "reasons: #{format_mix(data[:closure_reason_mix])}; " \
              "triggers: #{format_mix(data[:trigger_action_mix])}; intents: #{format_mix(data[:intent_reason_mix])}"
          end

          def format_mix(mix)
            mix.sort_by { |key, _count| key.to_s }.map { |key, count| "#{key}=#{count}" }.join(', ')
          end

          def format_opening_execution
            entries = aggregate[:opening_execution]
            return ' none' if entries.empty?

            format_block(entries.map do |entry|
              [
                "Seed #{entry[:seed]} #{entry[:corporation]}",
                "president=#{entry[:president]}",
                "auction=#{format_money(entry[:concession_auction_price])}",
                "par=#{format_money(entry[:par_price])}",
                "units=#{format_units(entry[:president_units_first_or], entry[:presidency_target_units])}",
                "depth=#{entry[:takeover_depth_first_or] || 'n/a'}",
                "treasury=#{format_money(entry[:treasury_after_first_sr])}",
                "train=#{format_opening_train(entry[:first_train])}",
                format_opening_route(entry),
                "takeover=#{format_opening_event(entry[:takeover])}",
                "closed=#{format_opening_event(entry[:closure])}",
              ].join(' ')
            end)
          end

          def format_opening_route(entry)
            pieces = ["first_route=#{format_money(entry[:first_route_revenue])}"]
            bought_route = entry[:first_bought_train_route_revenue]
            if bought_route && bought_route != entry[:first_route_revenue]
              pieces << "first_bought_route=#{format_money(bought_route)}"
            end

            pieces.join(' ')
          end

          def format_money(amount)
            amount.nil? ? 'n/a' : "$#{amount}"
          end

          def format_units(units, target)
            return 'n/a' unless units

            target ? "#{units}/#{target}" : units.to_s
          end

          def format_opening_train(train)
            return 'none' unless train

            "#{train[:train]}@#{format_money(train[:price])}"
          end

          def format_opening_event(event)
            return 'none' unless event

            pieces = []
            pieces << event[:player] if event[:player]
            pieces << event[:reason] if event[:reason]
            pieces << event[:round] if event[:round]
            pieces.empty? ? 'yes' : pieces.join('/')
          end

          def format_train_lifecycle
            format_block(ordered_train_entries(aggregate[:train_lifecycle]).map do |train, counts|
              "#{train} bought=#{counts[:purchased]} exported=#{counts[:exported]} runs=#{counts[:runs]} " \
                "runs/bought=#{counts[:runs_per_purchase]} avg_price=#{counts[:average_purchase_price]} " \
                "rev/bought=#{counts[:revenue_per_purchase]} rev/$=#{counts[:revenue_per_price]}"
            end)
          end

          def format_train_performance
            format_block(ordered_train_entries(aggregate[:train_performance]).map do |train, data|
              "#{train} runs=#{data[:average_runs]} avg=#{data[:average_revenue]}"
            end)
          end

          def format_late_non_permanent_four_runs
            runs = aggregate[:late_non_permanent_four_runs]
            return 'none' if runs.empty?

            formatted = runs.first(10).map do |run|
              "seed #{run[:seed]} #{run[:corporation]} OR #{run[:operating_round]} revenue=#{run[:revenue]}"
            end
            formatted << "... #{runs.size - formatted.size} more" if runs.size > formatted.size
            formatted.join(', ')
          end

          def format_zero_three_city_stops
            stops = aggregate[:zero_three_city_stops]
            return 'none' if stops.empty?

            stops.sort_by { |hex, data| [-data[:hits], hex] }.map do |hex, data|
              "#{hex}=#{data[:hits]} avg=#{data[:average_route_revenue]}"
            end.join(', ')
          end

          def format_city_hotspots
            format_block(aggregate[:city_hotspots].first(CITY_HOTSPOT_LIMIT).map do |data|
              "#{data[:label]} revenue=#{data[:revenue]} hits=#{data[:hits]} avg=#{data[:average_revenue]}"
            end)
          end

          def format_block(items)
            return ' none' if items.empty?

            "\n    #{items.join("\n    ")}"
          end

          def ordered_train_entries(entries)
            entries.sort_by { |train, _data| train_report_sort_key(train) }
          end

          def train_report_sort_key(train)
            [TRAIN_REPORT_ORDER.fetch(train.to_s, TRAIN_REPORT_ORDER.size), train.to_s]
          end

          def format_peak_player_cash
            data = aggregate[:peak_player_cash]
            "avg=#{data[:average]} max=#{data[:max]}"
          end

          def format_winner_closure_games
            data = aggregate[:winner_closure_games]
            "#{data[:games]} / #{data[:completed_games]} games (#{data[:percentage]}%)"
          end

          def format_winner_train_payouts
            ordered_train_entries(aggregate[:winner_train_payouts]).map do |train, data|
              "#{train}=#{data[:amount]} (#{data[:payouts]} payouts)"
            end.join(', ')
          end

          def format_winner_presidencies
            format_mix(aggregate[:winner_presidencies])
          end

          def format_ic_formation_timing
            data = aggregate[:ic_formation_timing]
            return 'none' if data[:games].zero?

            "games=#{data[:games]} / #{data[:completed_games]} (#{data[:percentage]}%), " \
              "phases: #{format_mix(data[:phase_mix])}; ORs: #{format_mix(data[:operating_round_mix])}"
          end

          def format_ic_non_formation
            data = aggregate[:ic_non_formation]
            return 'none' if data[:games].zero?

            "games=#{data[:games]} / #{data[:report_games]} (#{data[:percentage]}%), " \
              "reasons: #{format_mix(data[:reason_mix])}; phases: #{format_mix(data[:phase_mix])}; " \
              "avg completed=#{data[:average_completed_hexes]} / #{data[:required_count]}; " \
              "common missing: #{format_missing_ic_line_hexes(data[:missing_hexes])}"
          end

          def format_ic_non_formation_games
            entries = ic_non_formation_summaries
            return ' none' if entries.empty?

            "\n" + entries.map do |summary|
              data = summary[:ic_non_formation]
              phase = data[:phase] || 'unknown'
              round = data[:operating_round] ? "OR #{data[:operating_round]}" : data[:round]
              turn = data[:turn] || summary[:turn]
              round ||= turn ? "turn #{turn}" : 'unknown round'
              missing = format_missing_ic_line_hexes(data.fetch(:missing_hexes, []))

              "    Seed #{summary[:seed]}: #{data[:reason]}, phase #{phase}, #{round}, " \
                "completed #{data[:completed_count]}/#{data[:required_count]}, missing #{missing}"
            end.join("\n")
          end

          def format_missing_ic_line_hexes(missing_hexes)
            return 'none' if missing_hexes.empty?
            return missing_hexes.sort.join(', ') if missing_hexes.is_a?(Array)

            format_mix(missing_hexes)
          end

          def format_track_tile_usage
            aggregate[:track_tile_usage].map do |tile, data|
              "##{tile} avg=#{data[:average]} max=#{data[:max]}"
            end.join(', ')
          end

          def seat_results
            (1..max_player_count).map do |seat|
              results = completed_summaries.filter_map { |summary| summary[:players].find { |player| player[:seat] == seat } }
              {
                seat: seat,
                name: "Seat #{seat}",
                wins: results.count { |result| result[:rank] == 1 },
                average_value: average(results.map { |result| result[:value] }),
              }
            end
          end

          def completed_summaries
            summaries.select { |summary| summary[:status] == 'finished' }
          end

          def report_summaries
            completed_summaries.empty? ? summaries : completed_summaries
          end

          def metric_totals
            summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary[:metrics].each { |metric, value| totals[metric] += value }
            end.to_h
          end

          def metric_averages
            metric_averages_for(report_summaries)
          end

          def metric_averages_for(source_summaries)
            keys = %i[
              auction_bids corporations_started conversions share_purchases player_share_sales
              private_acquisitions train_purchases track_lays token_placements private_ability_uses
              routes_run route_revenue
            ]
            keys.to_h do |key|
              [key, average(source_summaries.map { |summary| summary.fetch(:metrics, {}).fetch(key, 0) })]
            end
          end

          def train_mix(source_summaries = summaries)
            source_summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary[:train_mix].each { |train, count| totals[train] += count }
            end.to_h
          end

          def par_mix(source_summaries = summaries)
            source_summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary[:par_mix].each { |price, count| totals[price] += count }
            end.to_h
          end

          def average_corporations_per_player_for(source_summaries)
            average(
              source_summaries.flat_map { |summary| summary[:players].map { |player| openings_for(summary, player[:name]) } },
            )
          end

          def player_count_mix
            summaries.each_with_object(Hash.new(0)) do |summary, totals|
              count = summary_player_count(summary)
              totals[count] += 1 if count.positive?
            end.to_h
          end

          def player_count_breakdown
            report_summaries.group_by { |summary| summary_player_count(summary) }
              .sort_by { |count, _group| count }
              .to_h do |count, group|
                [count, {
                  games: group.size,
                  average_actions: average(group.map { |summary| summary[:actions_taken] }),
                  metric_averages: metric_averages_for(group),
                  par_mix: par_mix(group),
                  train_mix: train_mix(group),
                  average_corporations_opened: average(group.map { |summary| summary[:par_events].size }),
                  average_corporations_per_player: average_corporations_per_player_for(group),
                  train_lifecycle: train_lifecycle(group),
                  train_performance: train_performance(group),
                }]
              end
          end

          def configured_player_counts
            case players
            when Range
              players.to_a.map(&:to_i)
            when Array
              players.map(&:to_i)
            else
              [players.to_i]
            end.reject(&:zero?)
          end

          def summary_player_count(summary)
            count = summary[:player_count].to_i
            return count if count.positive?

            count = summary.fetch(:players, []).size
            return count if count.positive?

            configured_player_counts.first.to_i
          end

          def max_player_count
            (summaries.map { |summary| summary_player_count(summary) } + configured_player_counts).max.to_i
          end

          def mixed_player_counts?
            player_count_mix.keys.size > 1 || configured_player_counts.uniq.size > 1
          end

          def openings_for(summary, player_name)
            summary[:par_events].count { |event| event[:player] == player_name }
          end

          def corporation_closures(summary)
            summary.fetch(:closure_events, []).size
          end

          def closures_by_corporation
            completed_summaries.each_with_object(Hash.new(0)) do |summary, totals|
              summary.fetch(:closure_events, []).each do |event|
                totals[event[:corporation]] += 1
              end
            end.to_h
          end

          def closure_events
            completed_summaries.flat_map do |summary|
              summary.fetch(:closure_events, []).map { |event| event.merge(seed: summary[:seed]) }
            end
          end

          def opening_execution
            report_summaries.flat_map do |summary|
              summary.fetch(:opening_execution, []).map { |entry| entry.merge(seed: summary[:seed]) }
            end
          end

          def closure_diagnostics
            events = closure_events
            route_revenues = events.filter_map { |event| event[:last_route_revenue] }
            planned = events.count { |event| event[:closure_intent] }
            {
              total: events.size,
              planned: planned,
              unplanned: events.size - planned,
              with_trains: events.count { |event| event[:train_count].to_i.positive? },
              active_operators: events.count { |event| event[:active_operator] },
              with_permanent: events.count { |event| event[:permanent_train] },
              average_last_route_revenue: average(route_revenues),
              closure_reason_mix: event_mix(events, :closure_reason),
              trigger_action_mix: event_mix(events, :trigger_action),
              intent_reason_mix: closure_intent_reason_mix(events),
            }
          end

          def closure_intent_reason_mix(events)
            events.each_with_object(Hash.new(0)) do |event, totals|
              reason = event.dig(:closure_intent, :reason) || 'none'
              totals[reason] += 1
            end.to_h
          end

          def par_by_corporation
            summaries.flat_map { |summary| summary[:par_events] }.each_with_object({}) do |event, totals|
              totals[event[:corporation]] ||= Hash.new(0)
              totals[event[:corporation]][event[:price]] += 1
            end.transform_values(&:to_h)
          end

          def peak_player_cash
            peaks = summaries.map { |summary| summary.fetch(:peak_player_cash, 0) }
            { average: average(peaks), max: peaks.max || 0 }
          end

          def track_tile_usage
            TRACK_TILE_USAGE_IDS.to_h do |tile|
              counts = summaries.map { |summary| summary.fetch(:track_tile_usage, {}).fetch(tile, 0) }
              [tile, { average: average(counts), max: counts.max || 0 }]
            end
          end

          def train_lifecycle(source_summaries = report_summaries)
            trains = source_summaries.flat_map do |summary|
              summary.fetch(:train_events, []).map { |event| train_event_bucket(event[:train]) } +
                summary.fetch(:train_runs, []).map { |run| train_run_bucket(run) }
            end.compact.uniq

            trains.to_h do |train|
              purchase_bucket = lifecycle_purchase_bucket(train)
              purchase_events = source_summaries.flat_map { |summary| summary.fetch(:train_events, []) }
                .select { |event| event[:train] == purchase_bucket && event[:event] == 'purchased' }
              total_purchases = purchase_events.size
              total_purchase_price = purchase_events.sum { |event| event[:price].to_i }
              total_revenue = source_summaries.flat_map { |summary| summary.fetch(:train_runs, []) }
                .select { |run| train_run_bucket(run) == train }
                .sum { |run| route_revenue_value(run) }
              purchases = source_summaries.map do |summary|
                summary.fetch(:train_events, []).count do |event|
                  event[:train] == purchase_bucket && event[:event] == 'purchased'
                end
              end
              exports = source_summaries.map do |summary|
                summary.fetch(:train_events, []).count { |event| event[:train] == purchase_bucket && event[:event] == 'exported' }
              end
              runs = source_summaries.map do |summary|
                summary.fetch(:train_runs, []).count { |run| train_run_bucket(run) == train }
              end
              [train, lifecycle_data(purchases, exports, runs, total_purchases, total_revenue, total_purchase_price)]
            end
          end

          def train_performance(source_summaries = report_summaries)
            runs = source_summaries.flat_map { |summary| summary[:train_runs] }
            train_performance_for(runs.group_by { |run| train_run_bucket(run) }, source_summaries)
          end

          def late_non_permanent_four_runs
            report_summaries.flat_map do |summary|
              final_set = final_operating_set(summary)
              next [] unless final_set

              summary.fetch(:train_runs, []).filter_map do |run|
                next unless operating_set_key(run) == final_set
                next unless non_permanent_four_run?(run)

                {
                  seed: summary[:seed],
                  corporation: run[:corporation],
                  operating_round: operating_round_key(run) || operating_set_key(run),
                  revenue: route_revenue_value(run),
                }
              end
            end
          end

          def zero_three_city_stops
            report_summaries.flat_map { |summary| summary.fetch(:train_runs, []) }
              .select { |run| train_run_bucket(run) == '0+3C' }
              .each_with_object({}) do |run, totals|
                run.fetch(:stops, []).select { |stop| stop[:type] == 'city' }.each do |stop|
                  hex = stop[:hex]
                  totals[hex] ||= { hits: 0, total_route_revenue: 0 }
                  totals[hex][:hits] += 1
                  totals[hex][:total_route_revenue] += route_revenue_value(run)
                end
              end.transform_values do |data|
                {
                  hits: data[:hits],
                  average_route_revenue: ratio(data[:total_route_revenue], data[:hits]),
                }
              end
          end

          def city_hotspots
            totals = Hash.new do |hash, hex|
              hash[hex] = {
                hex: hex,
                location_name: nil,
                revenue: 0,
                hits: 0,
              }
            end

            report_summaries.flat_map { |summary| summary.fetch(:train_runs, []) }.each do |run|
              run.fetch(:stops, []).select { |stop| stop[:type] == 'city' }.each do |stop|
                data = totals[stop[:hex]]
                data[:location_name] ||= stop[:location_name]
                data[:revenue] += stop[:revenue].to_i
                data[:hits] += 1
              end
            end

            totals.values
              .map do |data|
                data.merge(
                  label: city_hotspot_label(data),
                  average_revenue: ratio(data[:revenue], data[:hits]),
                )
              end
              .sort_by { |data| [-data[:revenue], -data[:hits], data[:hex].to_s] }
          end

          def city_hotspot_label(data)
            return data[:hex].to_s unless data[:location_name]

            "#{data[:location_name]} (#{data[:hex]})"
          end

          def train_performance_for(grouped_runs, source_summaries = report_summaries)
            grouped_runs.to_h do |train, train_runs|
              revenues = train_runs.map { |run| route_revenue_value(run) }
              average_runs = average(source_summaries.map do |summary|
                summary.fetch(:train_runs, []).count { |run| train_run_bucket(run) == train }
              end)
              [train, {
                runs: train_runs.size,
                average_runs: average_runs,
                total_revenue: revenues.sum,
                average_revenue: average(revenues),
              }]
            end
          end

          def train_run_bucket(run)
            return '4+2C + Pullman 4' if run[:train] == '4+2C' || pullman_struck_four_run?(run)
            return '5+1C + Pullman 5' if run[:train] == '5+1C' || pullman_struck_five_run?(run)

            run[:train]
          end

          def non_permanent_four_run?(run)
            train_run_bucket(run) == '4'
          end

          def final_operating_set(summary)
            summary.fetch(:train_runs, [])
              .filter_map { |run| operating_set_key(run) }
              .max_by { |operating_set| operating_set.to_i }
          end

          def operating_round_key(run)
            return run[:operating_round] if run[:operating_round]
            return unless run[:turn] && run[:round_num]

            "#{run[:turn]}.#{run[:round_num]}"
          end

          def operating_set_key(run)
            return run[:turn].to_s if run[:turn]
            return unless run[:operating_round]

            run[:operating_round].to_s.split('.').first
          end

          def route_revenue_value(run)
            run.fetch(:adjusted_revenue, run[:revenue]).to_i
          end

          def train_event_bucket(train)
            case train
            when '4+2C'
              '4+2C + Pullman 4'
            when '5+1C'
              '5+1C + Pullman 5'
            else
              train
            end
          end

          def lifecycle_purchase_bucket(train)
            case train
            when '4+2C + Pullman 4'
              '4+2C'
            when '5+1C + Pullman 5'
              '5+1C'
            else
              train
            end
          end

          def lifecycle_data(purchases, exports, runs, total_purchases, total_revenue, total_purchase_price)
            {
              purchased: average(purchases),
              exported: average(exports),
              runs: average(runs),
              runs_per_purchase: ratio(runs.sum, total_purchases),
              average_purchase_price: ratio(total_purchase_price, total_purchases),
              revenue_per_purchase: ratio(total_revenue, total_purchases),
              revenue_per_price: ratio(total_revenue, total_purchase_price),
            }
          end

          def ratio(numerator, denominator)
            return 0 if denominator.to_f.zero?

            (numerator.to_f / denominator).round(2)
          end

          def pullman_struck_four_run?(run)
            run[:train] == '4' && run[:original_train] == '4+2C'
          end

          def pullman_struck_five_run?(run)
            run[:train] == '5' && run[:original_train] == '5+1C'
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

          def ic_winner_count
            winner_presidencies.fetch('IC', 0)
          end

          def ic_formation_timing
            events = completed_summaries.filter_map { |summary| summary[:ic_formation] }
            completed = completed_summaries.size
            {
              games: events.size,
              completed_games: completed,
              percentage: ratio(events.size * 100, completed),
              phase_mix: event_mix(events, :phase),
              operating_round_mix: event_mix(events, :operating_round),
            }
          end

          def ic_non_formation
            non_formations = ic_non_formation_summaries.map { |summary| summary[:ic_non_formation] }
            required_count = non_formations.map { |entry| entry[:required_count] }.compact.max || 0
            {
              games: non_formations.size,
              report_games: completed_summaries.size,
              percentage: ratio(non_formations.size * 100, completed_summaries.size),
              reason_mix: event_mix(non_formations, :reason),
              phase_mix: event_mix(non_formations, :phase),
              average_completed_hexes: average(non_formations.map { |entry| entry[:completed_count] }),
              required_count: required_count,
              missing_hexes: missing_ic_line_hexes(non_formations),
            }
          end

          def ic_non_formation_summaries
            completed_summaries.select { |summary| summary[:ic_non_formation] }
          end

          def missing_ic_line_hexes(non_formations)
            non_formations.each_with_object(Hash.new(0)) do |entry, totals|
              entry.fetch(:missing_hexes, []).each { |hex| totals[hex] += 1 }
            end.to_h
          end

          def event_mix(events, key)
            events.each_with_object(Hash.new(0)) do |event, counts|
              counts[event[key] || 'unknown'] += 1
            end.to_h
          end

          def winner_closure_games
            count = completed_summaries.count do |summary|
              winner = summary[:players].find { |player| player[:rank] == 1 }
              next false unless winner

              summary.fetch(:closure_events, []).any? do |event|
                closure_event_player(summary, event) == winner[:name]
              end
            end
            completed = completed_summaries.size
            { games: count, completed_games: completed, percentage: ratio(count * 100, completed) }
          end

          def closure_event_player(summary, event)
            event[:player] || summary.fetch(:presidency_events, [])
              .reverse.find do |presidency|
                                presidency[:corporation] == event[:corporation] &&
                                              presidency[:turn].to_i <= event[:turn].to_i
                              end&.dig(:player)
          end

          def personality_usage_by_seat
            totals = (1..max_player_count).to_h { |seat| [seat, Hash.new(0)] }
            summaries.each do |summary|
              Array(summary[:profiles]).each do |profile|
                totals[profile[:seat]][profile[:profile]] += 1
              end
            end
            totals.transform_values(&:to_h)
          end

          def personality_results
            results = Hash.new { |hash, profile| hash[profile] = { appearances: 0, wins: 0, winner_values: [] } }
            completed_summaries.each do |summary|
              profiles = Array(summary[:profiles]).to_h { |profile| [profile[:seat], profile[:profile]] }
              profiles.each_value { |profile| results[profile][:appearances] += 1 }

              winner = summary[:players].find { |player| player[:rank] == 1 }
              next unless winner

              profile = profiles[winner[:seat]]
              next unless profile

              results[profile][:wins] += 1
              results[profile][:winner_values] << winner[:value]
            end

            results.sort_by { |profile, data| [-data[:wins], profile] }.to_h.transform_values do |data|
              {
                appearances: data[:appearances],
                wins: data[:wins],
                win_rate: ratio(data[:wins] * 100, data[:appearances]),
                average_winner_value: average(data[:winner_values]),
              }
            end
          end

          def opening_corporations_by_seat
            totals = (1..max_player_count).to_h { |seat| [seat, Hash.new(0)] }
            report_summaries.each do |summary|
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
            action_id = action[:action_id] ? "A#{action[:action_id]} | " : ''
            "#{action_id}T#{action[:turn]} #{action[:round]} | #{action[:entity]} | #{action[:step]} | #{action[:action]}"
          end
        end

        class BatchRunner
          attr_reader :games, :players, :optional_rules, :first_seed, :max_actions, :policy_factory, :on_game,
                      :crash_log_dir, :game_json_dir

          def self.summarize_result(result, seed, policy = nil)
            allocate.send(:summarize, result, seed, policy)
          end

          def initialize(games:, players:, optional_rules:, first_seed:, max_actions:, policy_factory:, on_game: nil,
                         crash_log_dir: nil, game_json_dir: nil)
            raise ArgumentError, 'games must be positive' unless games.positive?

            @games = games
            @player_counts = normalize_player_counts(players)
            @players = @player_counts.size == 1 && players.is_a?(Integer) ? @player_counts.first : @player_counts
            @optional_rules = optional_rules
            @first_seed = first_seed
            @max_actions = max_actions
            @policy_factory = policy_factory
            @on_game = on_game
            @crash_log_dir = crash_log_dir
            @game_json_dir = game_json_dir
          end

          def run
            summaries = Array.new(games) do |index|
              game_number = index + 1
              seed = first_seed + index
              started_at = monotonic_time
              summary = run_game(seed, game_number)
              summary[:elapsed_seconds] = elapsed_seconds_since(started_at)
              on_game&.call(game_number, games, summary)
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

          attr_reader :player_counts

          def normalize_player_counts(players)
            counts = case players
                     when Range
                       players.to_a
                     when Array
                       players
                     else
                       [players]
                     end.map(&:to_i)
            raise ArgumentError, 'players must include at least one positive count' if counts.empty? || counts.any? { |count| count <= 0 }

            counts
          end

          def players_for_game(game_number)
            player_counts[(game_number - 1) % player_counts.size]
          end

          def with_player_count(player_count)
            previous = @current_player_count
            @current_player_count = player_count
            yield
          ensure
            @current_player_count = previous
          end

          def current_player_count
            @current_player_count || player_counts.first
          end

          def run_game(seed, game_number)
            player_count = players_for_game(game_number)
            with_player_count(player_count) do
              return run_game_in_process(seed, game_number) unless Process.respond_to?(:fork)

              summary = run_game_in_child(seed, game_number, 1)
              return attach_seed_crash_logs(summary, seed) if summary&.dig(:status) == 'finished'

              summary = run_game_in_child(seed, game_number, 2)
              return attach_seed_crash_logs(summary, seed) if summary

              crashed_worker_summary(seed)
            end
          end

          def run_game_in_process(seed, game_number)
            policy = policy_for_seed(seed)
            result = run_bot(seed, policy)
            summary = summarize(result, seed, policy)
            summary[:player_count] ||= current_player_count
            write_game_json(summary, result, game_number)
          rescue StandardError => e
            worker_error_summary(seed, e)
          end

          def run_game_in_child(seed, game_number, attempt)
            log_path = crash_log_path(seed, attempt)
            reader, writer = IO.pipe
            pid = Process.fork do
              reader.close
              redirect_child_error_log(log_path)
              payload = run_game_in_process(seed, game_number)
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
            $stderr.reopen(file)
            $stderr.sync = true
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

          def policy_for_seed(seed)
            return PolicyRoster.new(PolicyProfile.random_roster(current_player_count, seed: seed)) unless policy_factory

            case policy_factory.arity
            when 0
              policy_factory.call
            when 1
              policy_factory.call(seed)
            else
              policy_factory.call(seed, current_player_count)
            end
          end

          def run_bot(seed, policy)
            Bot.run(
              players: current_player_count,
              optional_rules: optional_rules,
              seed: seed,
              max_actions: max_actions,
              policy: policy,
            )
          end

          def write_game_json(summary, result, game_number)
            return summary unless game_json_dir && result&.game

            FileUtils.mkdir_p(game_json_dir)
            path = game_json_path(summary[:seed], game_number)
            HotseatExporter.new(result).write(path, validate: false)
            summary[:game_json_path] = path
            summary
          rescue StandardError => e
            summary[:game_json_error] = "#{e.class}: #{e.message}"
            summary
          end

          def game_json_path(seed, game_number)
            File.join(
              game_json_dir,
              format('game_%<number>03d_seed_%<seed>s.json', number: game_number, seed: seed),
            )
          end

          def monotonic_time
            if Process.respond_to?(:clock_gettime) && defined?(Process::CLOCK_MONOTONIC)
              Process.clock_gettime(Process::CLOCK_MONOTONIC)
            else
              Time.now.to_f
            end
          end

          def elapsed_seconds_since(started_at)
            (monotonic_time - started_at).round(2)
          end

          def crashed_worker_summary(seed)
            {
              seed: seed,
              status: 'error',
              detail: 'Game worker crashed twice',
              player_count: current_player_count,
              actions_taken: 0,
              turn: nil,
              profiles: summarize_profiles(policy_for_seed(seed)),
              players: [],
              corporations: [],
              presidency_events: [],
              closure_events: [],
              par_events: [],
              opening_execution: [],
              train_events: [],
              train_runs: [],
              dividends: [],
              ic_formation: nil,
              peak_player_cash: 0,
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

          def summarize(result, seed, policy)
            game = result.game
            rankings = game.result.keys.each_with_index.to_h { |player_id, index| [player_id, index + 1] }
            ic_formation = summarize_ic_formation(result)
            {
              seed: seed,
              status: result.status.to_s,
              detail: result.detail,
              player_count: game.players.size,
              actions_taken: result.actions_taken,
              turn: game.turn,
              profiles: summarize_profiles(policy),
              players: summarize_players(game, rankings),
              corporations: summarize_corporations(game),
              presidency_events: result.events.to_a.select { |entry| entry[:event] == 'presidency' },
              closure_events: result.events.to_a.select { |entry| entry[:event] == 'corporation_close' },
              par_events: summarize_par_events(result.trace),
              opening_execution: summarize_opening_execution(result),
              train_events: summarize_train_events(result),
              train_runs: summarize_train_runs(result.trace),
              ic_formation: ic_formation,
              ic_non_formation: summarize_ic_non_formation(result, ic_formation),
              dividends: result.trace.select { |entry| entry[:action] == 'dividend' }.map do |entry|
                entry.slice(:corporation, :president, :kind, :revenue, :corporation_withheld, :player_payouts, :routes)
              end,
              peak_player_cash: result.peak_player_cash,
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

          def summarize_profiles(policy)
            return [] unless policy.respond_to?(:profiles)

            policy.profiles.map.with_index do |profile, index|
              { seat: index + 1, profile: profile.name }
            end
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

          def summarize_opening_execution(result)
            par_events = summarize_par_events(result.trace)
            return [] if par_events.empty?

            auction_by_corporation = opening_auction_by_corporation(result)
            snapshot = opening_snapshot_game(result)

            par_events.map do |par_event|
              corporation = snapshot_corporation(snapshot, par_event[:corporation])
              first_train = first_train_event(result, par_event[:corporation])
              first_route = first_route_event(result, par_event[:corporation])
              first_bought_train_route = first_bought_train_route_event(result, par_event[:corporation])
              takeover = takeover_event(result, par_event)
              closure = opening_closure_event(result, par_event[:corporation])

              {
                corporation: par_event[:corporation],
                president: par_event[:player],
                concession_auction_price: auction_by_corporation.dig(par_event[:corporation], :price),
                concession_auction_winner: auction_by_corporation.dig(par_event[:corporation], :player),
                par_price: par_event[:price],
                president_units_first_or: president_units_for(corporation),
                presidency_target_units: opening_presidency_target_units(corporation, par_event[:price]),
                takeover_depth_first_or: opening_takeover_depth(corporation),
                treasury_after_first_sr: corporation&.cash,
                first_train: first_train&.slice(:train, :price, :turn, :round),
                first_route_revenue: first_route&.dig(:route_revenue),
                first_route: first_route&.slice(:turn, :round, :route_revenue, :trains_run),
                first_bought_train_route_revenue: first_bought_train_route&.dig(:route_revenue),
                first_bought_train_route: first_bought_train_route&.slice(:turn, :round, :route_revenue, :trains_run),
                takeover: takeover&.slice(
                  :player,
                  :turn,
                  :round,
                  :reason,
                  :trigger_action,
                  :trigger_entity,
                  :trigger_percent,
                ),
                closure: closure && {
                  reason: closure[:closure_reason],
                  turn: closure[:turn],
                  round: closure[:round],
                },
              }.compact
            end
          rescue StandardError => e
            [{ diagnostic_error: "#{e.class}: #{e.message}" }]
          end

          def opening_auction_by_corporation(result)
            result.trace.select { |entry| entry[:action] == 'bid' }.each_with_object({}) do |entry, auctions|
              corporation = auction_corporation_for(result.game, entry[:company])
              next unless corporation

              auctions[corporation] = { price: entry[:price], player: entry[:entity], turn: entry[:turn] }
            end
          end

          def auction_corporation_for(game, company_name)
            company = game.companies.find { |candidate| [candidate.id, candidate.name].include?(company_name) }
            return company.sym if company&.meta&.dig(:type) == :concession

            definitions = game.respond_to?(:game_companies) ? game.game_companies : []
            company_definition = Array(definitions).find do |candidate|
              [candidate[:sym], candidate[:name]].include?(company_name)
            end
            return company_definition[:sym] if company_definition&.dig(:meta, :type) == :concession

            company_name
          end

          def opening_snapshot_game(result)
            game = result.game
            return game unless game.respond_to?(:clone) && game.respond_to?(:raw_actions)

            first_operating_index = result.trace.index do |entry|
              entry[:round].to_s.include?('Operating Round')
            end
            action_count = first_operating_index || result.trace.size
            game.clone(game.raw_actions.first(action_count))
          rescue StandardError
            game
          end

          def snapshot_corporation(game, corporation_name)
            if game.respond_to?(:corporation_by_id)
              game.corporation_by_id(corporation_name)
            else
              game.corporations.find { |corporation| corporation.name == corporation_name || corporation.id == corporation_name }
            end
          end

          def first_train_event(result, corporation)
            summarize_train_events(result).find do |event|
              event[:event] == 'purchased' && event[:corporation] == corporation
            end
          end

          def first_route_event(result, corporation)
            result.trace.find do |entry|
              entry[:action] == 'run_routes' && entry[:corporation] == corporation
            end
          end

          def first_bought_train_route_event(result, corporation)
            result.trace.find do |entry|
              next false unless entry[:action] == 'run_routes' && entry[:corporation] == corporation

              entry.fetch(:routes, []).any? { |route| !rogers_route?(route) }
            end
          end

          def rogers_route?(route)
            [route[:train], route[:original_train]].include?(ROGERS_TRAIN_NAME)
          end

          def takeover_event(result, par_event)
            presidency_events = result.events.to_a.select do |event|
              event[:event] == 'presidency' && event[:corporation] == par_event[:corporation]
            end
            first_presidency = presidency_events.index { |event| event[:player] == par_event[:player] } || -1

            event = presidency_events[(first_presidency + 1)..]&.find { |candidate| candidate[:player] != par_event[:player] }
            return unless event

            event.merge(reason: takeover_reason(event, par_event))
          end

          def takeover_reason(event, par_event)
            case event[:trigger_action]
            when 'sell_shares'
              event[:trigger_entity] == par_event[:player] ? 'president_sale' : 'sale_exposure'
            when 'buy_shares'
              event[:trigger_entity] == event[:player] ? 'rival_buy' : 'share_buy'
            else
              event[:trigger_action] || 'unknown'
            end
          end

          def opening_closure_event(result, corporation)
            result.events.to_a.find do |event|
              event[:event] == 'corporation_close' && event[:corporation] == corporation
            end
          end

          def president_units_for(corporation)
            president = corporation&.owner
            return unless president&.player?

            (president.percent_of(corporation).to_f / corporation.share_percent).round(2)
          end

          def opening_presidency_target_units(corporation, par_price)
            return unless corporation

            case corporation.total_shares
            when 10
              par_price.to_i <= 40 ? 4 : 3
            when 5
              3
            else
              corporation.presidents_percent / corporation.share_percent
            end
          end

          def opening_takeover_depth(corporation)
            return unless corporation

            president_units = president_units_for(corporation)
            return unless president_units

            presidency_units = corporation.presidents_percent / corporation.share_percent
            [presidency_units, president_units + 1].max
          end

          def summarize_ic_formation(result)
            result.events.to_a.find { |entry| entry[:event] == 'ic_formation' }&.slice(
              :turn,
              :round,
              :round_num,
              :operating_round,
              :phase,
              :trigger_entity,
              :trigger_actor,
            )
          end

          def summarize_ic_non_formation(result, ic_formation)
            return unless result.status == :finished
            return if ic_formation

            game = result.game
            completed_hexes = Array(game.instance_variable_get(:@ic_line_completed_hexes)).map(&:id).sort
            required_count = game.class::IC_LINE_COUNT
            all_hexes = game.class::IC_LINE_ORIENTATION.keys.sort
            missing_hexes = (all_hexes - completed_hexes).sort
            round_num = game.round.respond_to?(:round_num) ? game.round.round_num : nil
            {
              reason: ic_non_formation_reason(game, completed_hexes.size, required_count),
              turn: game.turn,
              round: game.round&.name,
              round_num: round_num,
              operating_round: round_num ? "#{game.turn}.#{round_num}" : nil,
              phase: game.phase&.name,
              completed_count: completed_hexes.size,
              required_count: required_count,
              completed_hexes: completed_hexes,
              missing_hexes: missing_hexes,
              line_hexes: summarize_ic_line_hexes(game, completed_hexes),
            }
          end

          def ic_non_formation_reason(game, completed_count, required_count)
            return 'Intro game' if game.respond_to?(:intro_game?) && game.intro_game?
            return 'IC formation pending' if game.ic_formation_pending?
            return 'IC Line completed in phase D' if completed_count >= required_count && game.phase&.name == 'D'
            return 'IC Line incomplete' if completed_count < required_count
            return 'IC formation triggered but not observed' if game.ic_formation_triggered?

            'IC Line complete but formation not triggered'
          end

          def summarize_ic_line_hexes(game, completed_hexes)
            completed = completed_hexes.to_h { |hex| [hex, true] }
            game.class::IC_LINE_ORIENTATION.keys.sort.map do |hex_id|
              hex = game.hex_by_id(hex_id)
              {
                hex: hex_id,
                location_name: hex.location_name || hex.tile.location_name,
                connections: game.ic_line_connections(hex),
                completed: completed[hex_id] || false,
              }
            end
          end

          def summarize_train_events(result)
            purchases = result.trace.select { |entry| entry[:action] == 'buy_train' }.map do |entry|
              {
                event: 'purchased',
                train: entry[:train],
                corporation: entry[:corporation],
                price: entry[:price],
                turn: entry[:turn],
                round: entry[:round],
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
                seat: player_seat(player, index),
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

          def player_seat(player, index)
            id = player.id.to_s
            bot_seat = id[/\ABot (\d+)\z/, 1] || id[/\Aplayer_(\d+)\z/, 1]
            bot_seat&.to_i || (index + 1)
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

# rubocop:enable Security/MarshalLoad, Style/MultilineBlockChain, Style/UnlessLogicalOperators
