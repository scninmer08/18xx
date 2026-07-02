# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Bot
        Result = Struct.new(:status, :game, :actions_taken, :detail, :trace, :error_backtrace, keyword_init: true)

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
            actions_taken = 0

            until game.finished
              while game.round.finished? && !game.finished
                game.transition_to_next_round!
              end

              if actions_taken >= max_actions
                return result(:limit, actions_taken, trace, "Reached the #{max_actions}-action limit")
              end

              decision = policy.choose(game)
              return result(:blocked, actions_taken, trace, blocked_detail(decision.reason)) if decision.action.nil?

              entry = trace_entry(decision)
              trace << entry
              on_action&.call(entry)
              game.process_action(decision.action)
              actions_taken += 1

              if game.exception
                return result(
                  :error,
                  actions_taken,
                  trace,
                  game.exception.message,
                  error_backtrace: game.exception.backtrace,
                )
              end
            end

            result(:finished, actions_taken, trace, 'Game completed')
          end

          private

          def result(status, actions_taken, trace, detail, error_backtrace: nil)
            Result.new(
              status: status,
              game: game,
              actions_taken: actions_taken,
              detail: detail,
              trace: trace,
              error_backtrace: error_backtrace,
            )
          end

          def trace_entry(decision)
            action = decision.action
            entry = {
              turn: game.turn,
              round: game.round.name,
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
              { corporation: action.entity.name, train: action.variant || action.train.name, price: action.price }
            when Engine::Action::BorrowTrain
              { corporation: action.entity.name, train: action.train.name }
            when Engine::Action::LayTile
              { corporation: action.entity.name, hex: action.hex.id, tile: action.tile.name }
            when Engine::Action::PlaceToken
              { corporation: action.entity.name, hex: action.city.hex.id, city: action.city.index }
            when Engine::Action::RunRoutes
              {
                corporation: action.entity.name,
                route_revenue: game.routes_revenue(action.routes),
                subsidy: action.subsidy,
                trains_run: action.routes.size,
              }
            else
              {}
            end
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
