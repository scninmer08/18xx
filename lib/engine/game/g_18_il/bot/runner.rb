# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Bot
        Result = Struct.new(
          :status,
          :game,
          :actions_taken,
          :detail,
          :trace,
          :events,
          :peak_player_cash,
          :error_backtrace,
          keyword_init: true,
        )

        class Runner
          attr_reader :game, :policy, :max_actions, :on_action

          def self.format_trace_entry(entry)
            "T#{entry[:turn]} #{entry[:round]} | #{entry[:entity]} | #{entry[:step]} | " \
              "#{entry[:action]}: #{entry[:reason]}"
          end

          def initialize(game, policy: BaselinePolicy.new, max_actions: 1_000, on_action: nil)
            @game = game
            @policy = policy
            @max_actions = max_actions
            @on_action = on_action
          end

          def run
            trace = []
            @events = []
            @presidencies = presidency_state
            @closed_corporations = closed_corporation_state
            @ic_formation_triggered = game.ic_formation_triggered?
            @train_origins = {}
            @last_route_revenue_by_corporation = {}
            peak_player_cash = total_player_cash
            actions_taken = 0

            until game.finished
              while game.round.finished? && !game.finished
                observe_train_exports(context: round_transition_context) { game.transition_to_next_round! }
              end

              if actions_taken >= max_actions
                return result(:limit, actions_taken, trace, "Reached the #{max_actions}-action limit",
                              peak_player_cash: peak_player_cash)
              end

              decision = policy.choose(game)
              if decision.action.nil?
                return result(:blocked, actions_taken, trace, blocked_detail(decision.reason),
                              peak_player_cash: peak_player_cash)
              end

              entry = trace_entry(decision)
              trace << entry
              on_action&.call(entry)
              observe_train_exports(context: entry) { game.process_action(decision.action) }
              peak_player_cash = [peak_player_cash, total_player_cash].max
              actions_taken += 1

              if game.exception
                return result(
                  :error,
                  actions_taken,
                  trace,
                  game.exception.message,
                  peak_player_cash: peak_player_cash,
                  error_backtrace: game.exception.backtrace,
                )
              end
            end

            result(:finished, actions_taken, trace, 'Game completed', peak_player_cash: peak_player_cash)
          end

          private

          def result(status, actions_taken, trace, detail, peak_player_cash: total_player_cash, error_backtrace: nil)
            Result.new(
              status: status,
              game: game,
              actions_taken: actions_taken,
              detail: detail,
              trace: trace,
              events: @events,
              peak_player_cash: peak_player_cash,
              error_backtrace: error_backtrace,
            )
          end

          def trace_entry(decision)
            action = decision.action
            round_num = game.round.respond_to?(:round_num) ? game.round.round_num : nil
            entry = {
              turn: game.turn,
              round: game.round.name,
              round_num: round_num,
              operating_round: round_num ? "#{game.turn}.#{round_num}" : nil,
              step: game.round.active_step.description,
              entity: action.entity.name,
              entity_type: entity_type(action.entity),
              action: action.type,
              reason: decision.reason,
            }
            entry.merge!(action_details(action))
            entry
          end

          def entity_type(entity)
            return 'player' if entity.player?
            return 'company' if entity.company?

            entity.type.to_s
          end

          def action_details(action)
            case action
            when Engine::Action::Bid
              { company: action.company&.name, price: action.price }
            when Engine::Action::Par
              { corporation: action.corporation.name, price: action.share_price.price }
            when Engine::Action::Convert
              { corporation: action.entity.name }
            when Engine::Action::BuyShares, Engine::Action::SellShares
              {
                corporation: action.bundle.corporation.name,
                percent: action.bundle.percent,
                price: action.bundle.price,
              }
            when Engine::Action::AcquireCompany
              { corporation: action.entity.name, company: action.company.name }
            when Engine::Action::BuyTrain
              train_origin = train_origin_for_purchase(action)
              @train_origins[action.train.id] ||= train_origin
              {
                corporation: train_buyer(action.entity).name,
                train: action.variant || action.train.name,
                train_id: action.train.id,
                original_train: @train_origins[action.train.id],
                price: action.price,
                seller: action.train.owned_by_corporation? ? action.train.owner.name : 'Depot',
                buyer_president: train_buyer(action.entity).owner&.name,
                seller_president: action.train.owned_by_corporation? ? action.train.owner.owner&.name : nil,
              }
            when Engine::Action::BorrowTrain, Engine::Action::DiscardTrain
              { corporation: action.entity.name, train: action.train.name }
            when Engine::Action::LayTile
              { corporation: action.entity.name, hex: action.hex.id, tile: action.tile.name }
            when Engine::Action::PlaceToken
              { corporation: action.entity.name, hex: action.city.hex.id, city: action.city.index }
            when Engine::Action::RunRoutes
              route_revenue = game.routes_revenue(action.routes)
              @last_route_revenue_by_corporation[action.entity.name] = route_revenue
              {
                corporation: action.entity.name,
                president: action.entity.owner&.name,
                route_revenue: route_revenue,
                subsidy: action.subsidy,
                trains_run: action.routes.size,
                routes: action.routes.map do |route|
                  route_details(route)
                end,
              }
            when Engine::Action::Dividend
              dividend_details(action)
            else
              {}
            end
          end

          def dividend_details(action)
            step = game.round.active_step
            revenue = step.total_revenue
            payout = step.dividend_options(action.entity)[action.kind.to_sym]
            per_share = payout[:per_share]
            player_payouts = game.players.to_h do |player|
              [player.name, step.dividends_for_entity(action.entity, player, per_share)]
            end
            player_payouts.reject! { |_player, amount| amount.zero? }

            {
              corporation: action.entity.name,
              president: action.entity.owner&.name,
              kind: action.kind,
              revenue: revenue,
              corporation_withheld: payout[:corporation],
              player_payouts: player_payouts,
              routes: step.routes.map { |route| route_details(route) },
            }
          end

          def route_details(route)
            extension = route_extension_details(route)
            train_name = extension&.fetch(:original_train) || route.train.name
            revenue = route.revenue
            adjusted_revenue = extension ? [revenue - extension[:lowest_revenue], 0].max : revenue
            {
              train: train_name,
              train_id: route.train.id,
              original_train: @train_origins[route.train.id] || route.train.name,
              revenue: revenue,
              adjusted_revenue: adjusted_revenue,
              revenue_str: route.revenue_str,
              stops: route.stops.map { |stop| route_stop_details(route, stop) },
            }.merge(extension || {})
          end

          def route_stop_details(route, stop)
            {
              hex: stop.hex&.id,
              location_name: stop.hex&.location_name || stop.hex&.tile&.location_name,
              type: route_stop_type(stop),
              index: stop.index,
              revenue: stop.route_revenue(route.phase, route.train),
              groups: stop.groups,
            }
          end

          def route_stop_type(stop)
            return 'city' if stop.city?
            return 'offboard' if stop.offboard?
            return 'town' if stop.town?

            'stop'
          end

          def route_extension_details(route)
            round = game.round
            return unless round.respond_to?(:route_extension_train)
            return unless round.route_extension_train == route.train
            return unless round.route_extension_original

            original = round.route_extension_original
            {
              route_extension: true,
              route_extension_train: route.train.name,
              original_train: original[:name],
              lowest_revenue: lowest_route_extension_revenue(route),
            }
          end

          def lowest_route_extension_revenue(route)
            stops = route.stops.select { |stop| stop.city? || stop.offboard? }
            stops.map { |stop| stop.route_revenue(route.phase, route.train) }.min.to_i
          end

          def train_origin_for_purchase(action)
            return @train_origins[action.train.id] if action.train.owned_by_corporation?

            action.variant || action.train.name
          end

          def total_player_cash
            game.players.sum(&:cash)
          end

          def train_buyer(entity)
            return entity unless entity.company?

            entity.owner&.corporation? ? entity.owner : entity
          end

          def observe_train_exports(context: nil)
            before = game.depot.upcoming.dup
            closed_before = @closed_corporations.dup
            closure_snapshots = closure_snapshots_by_name
            yield
            game.depot.upcoming.tap do |after|
              (before - after).each do |train|
                next if train.owner && train.owner != game.depot

                @events << {
                  event: 'train_export',
                  train: train.name,
                  turn: game.turn,
                  round: game.round&.name,
                }
              end
            end
            closed_after = closed_corporation_state
            (closed_after - closed_before).each do |corporation|
              company = game.company_by_id(corporation)
              snapshot = closure_snapshots.fetch(corporation, {})
              trigger = closure_trigger_details(context)
              @events << {
                event: 'corporation_close',
                corporation: corporation,
                player: company&.owner&.player? ? company.owner.name : nil,
                turn: game.turn,
                round: game.round&.name,
                closure_reason: closure_reason(snapshot, trigger),
              }.merge(snapshot).merge(trigger)
            end
            @closed_corporations = closed_after
            observe_ic_formation
            observe_presidency_changes(context)
          end

          def round_transition_context
            {
              action: 'transition_to_next_round',
              entity: game.round&.current_entity&.name,
              step: 'Round transition',
              reason: 'Round transition',
            }
          end

          def closure_snapshots_by_name
            game.corporations.each_with_object({}) do |corporation, snapshots|
              next if game.closed_corporations.include?(corporation)

              snapshots[corporation.name] = closure_snapshot(corporation)
            end
          end

          def closure_snapshot(corporation)
            @last_route_revenue_by_corporation ||= {}
            {
              president: corporation.owner&.name,
              share_price: corporation.share_price&.price,
              market_shares: corporation.num_market_shares,
              cash: corporation.cash,
              trains: corporation.trains.map(&:name),
              train_count: corporation.trains.size,
              permanent_train: corporation.trains.any? { |train| train.rusts_on.nil? && train.obsolete_on.nil? },
              last_route_revenue: @last_route_revenue_by_corporation[corporation.name],
              active_operator: active_operator_closure_snapshot?(corporation),
              closure_intent: closure_intent_snapshot(corporation),
            }.compact
          end

          def active_operator_closure_snapshot?(corporation)
            corporation.trains.any? && @last_route_revenue_by_corporation[corporation.name].to_i.positive?
          end

          def closure_intent_snapshot(corporation)
            return unless policy.respond_to?(:closure_intent_for)

            intent = policy.closure_intent_for(game, corporation)
            return unless intent

            intent.transform_values(&:to_s)
          end

          def closure_trigger_details(context)
            return {} unless context

            {
              trigger_action: context[:action],
              trigger_entity: context[:entity],
              trigger_step: context[:step],
              trigger_reason: context[:reason],
              trigger_corporation: context[:corporation],
            }.compact
          end

          def closure_reason(snapshot, trigger)
            return 'ic_merge' if trigger[:trigger_action] == 'merge' || trigger[:trigger_step] == 'Merger Compensation'
            return 'planned_market_close' if snapshot[:closure_intent]
            return 'market_close' if snapshot[:share_price].to_i.positive?

            'unknown'
          end

          def observe_ic_formation
            current = game.ic_formation_triggered?
            if current && !@ic_formation_triggered
              trigger_entity = game.ic_trigger_entity
              round_num = game.round.respond_to?(:round_num) ? game.round.round_num : nil
              @events << {
                event: 'ic_formation',
                turn: game.turn,
                round: game.round&.name,
                round_num: round_num,
                operating_round: round_num ? "#{game.turn}.#{round_num}" : game.turn.to_s,
                phase: game.phase&.name,
                trigger_entity: trigger_entity&.name,
                trigger_actor: ic_trigger_actor(trigger_entity),
              }
            end
            @ic_formation_triggered = current
          end

          def ic_trigger_actor(entity)
            return unless entity
            return entity.owner&.name if entity.company?

            entity.name
          end

          def observe_presidency_changes(context = nil)
            current = presidency_state
            current.each do |corporation, player|
              next if player.nil? || @presidencies[corporation] == player

              @events << {
                event: 'presidency',
                corporation: corporation,
                player: player,
                turn: game.turn,
                round: game.round&.name,
              }.merge(presidency_trigger_details(context))
            end
            @presidencies = current
          end

          def presidency_trigger_details(context)
            return {} unless context

            {
              trigger_action: context[:action],
              trigger_entity: context[:entity],
              trigger_step: context[:step],
              trigger_reason: context[:reason],
              trigger_corporation: context[:corporation],
              trigger_percent: context[:percent],
              trigger_price: context[:price],
            }.compact
          end

          def presidency_state
            (game.corporations + game.closed_corporations).uniq.to_h do |corporation|
              [corporation.name, corporation.owner&.player? ? corporation.owner.name : nil]
            end
          end

          def closed_corporation_state
            game.closed_corporations.map(&:name)
          end

          def blocked_detail(reason)
            step = game.round.active_step
            entity = game.round.current_entity
            actions = entity ? step&.actions(entity) || [] : []

            "#{reason}; turn #{game.turn}, #{game.round.name}, #{step&.description}, " \
              "entity #{entity&.name}, actions: #{actions.join(', ')}"
          end
        end
      end
    end
  end
end
