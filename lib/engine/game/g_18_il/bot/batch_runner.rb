# frozen_string_literal: true

require 'json'

module Engine
  module Game
    module G18IL
      module Bot
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
                           'Decision totals:',
                           "  Auction bids: #{aggregate[:metrics][:auction_bids]}",
                           "  Corporations started: #{aggregate[:metrics][:corporations_started]}",
                           "  Conversions: #{aggregate[:metrics][:conversions]}",
                           "  Share purchases: #{aggregate[:metrics][:share_purchases]}",
                           "  Player share sales: #{aggregate[:metrics][:player_share_sales]}",
                           "  Private acquisitions: #{aggregate[:metrics][:private_acquisitions]}",
                           "  Train purchases: #{aggregate[:metrics][:train_purchases]}",
                           "  Trains borrowed: #{aggregate[:metrics][:trains_borrowed]}",
                           "  Track lays: #{aggregate[:metrics][:track_lays]}",
                           "  Token placements: #{aggregate[:metrics][:token_placements]}",
                           "  Private ability uses: #{aggregate[:metrics][:private_ability_uses]}",
                           "  Routes run: #{aggregate[:metrics][:routes_run]}",
                           "  Route revenue: #{aggregate[:metrics][:route_revenue]}",
                           '',
                           "Par values: #{format_par_mix}",
                           "Train purchases by type: #{format_train_mix}",
                         ])
            failures = summaries.reject { |summary| summary[:status] == 'finished' }
            unless failures.empty?
              lines << ''
              lines << 'Incomplete games:'
              failures.each do |summary|
                lines << "  Seed #{summary[:seed]}: #{summary[:status]} - #{summary[:detail]}"
                last_action = summary.dig(:failure, :last_action)
                lines << "    Last action: #{format_last_action(last_action)}" if last_action
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

          def seat_results
            (1..players).map do |seat|
              results = summaries.filter_map { |summary| summary[:players].find { |player| player[:seat] == seat } }
              {
                seat: seat,
                name: "Bot #{seat}",
                wins: results.count { |result| result[:rank] == 1 },
                average_value: average(results.map { |result| result[:value] }),
              }
            end
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

          def average(values)
            return 0 if values.empty?

            (values.sum.to_f / values.size).round(1)
          end

          def format_last_action(action)
            "T#{action[:turn]} #{action[:round]} | #{action[:entity]} | #{action[:step]} | #{action[:action]}"
          end
        end

        class BatchRunner
          attr_reader :games, :players, :optional_rules, :first_seed, :max_actions, :policy_factory, :on_game

          def initialize(games:, players:, optional_rules:, first_seed:, max_actions:, policy_factory:, on_game: nil)
            raise ArgumentError, 'games must be positive' unless games.positive?

            @games = games
            @players = players
            @optional_rules = optional_rules
            @first_seed = first_seed
            @max_actions = max_actions
            @policy_factory = policy_factory
            @on_game = on_game
          end

          def run
            summaries = Array.new(games) do |index|
              seed = first_seed + index
              result = Bot.run(
                players: players,
                optional_rules: optional_rules,
                seed: seed,
                max_actions: max_actions,
                policy: policy_factory.call,
              )
              summary = summarize(result, seed)
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
              metrics: summarize_metrics(result.trace),
              par_mix: result.trace
                .select { |entry| entry[:action] == 'par' }
                .group_by { |entry| entry[:price] }
                .transform_values(&:size),
              train_mix: result.trace
                .select { |entry| entry[:action] == 'buy_train' }
                .group_by { |entry| entry[:train] }
                .transform_values(&:size),
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
              track_lays: trace.count { |entry| entry[:action] == 'lay_tile' },
              token_placements: trace.count { |entry| entry[:action] == 'place_token' },
              private_ability_uses: trace.count do |entry|
                entry[:entity_type] == 'company' || entry[:reason].start_with?('Uses Planned Obsolescence')
              end,
              routes_run: trace.count { |entry| entry[:action] == 'run_routes' },
              route_revenue: trace.sum { |entry| entry[:route_revenue].to_i + entry[:subsidy].to_i },
            }
          end
        end
      end
    end
  end
end
