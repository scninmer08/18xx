# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../step/share_buying'

module Engine
  module Game
    module G18FLOOD
      module Step
        class ShellPostSwapShares < Engine::Step::Base
          include Engine::Step::ShareBuying

          ACTIONS = %w[buy_shares pass].freeze

          # ------------------------------------------------------------------
          # Round state
          #   Expect @round.shell_ipo to be set by your game code like:
          #   @round.shell_ipo = {
          #     corp: <shell corp>,
          #     starter: <player who owns the parent>,
          #     phase: :starter,        # or :others
          #     remaining: 30,          # starter’s remaining percent
          #     cursor: 0,              # index into players after starter
          #     acted: {}               # others who already acted
          #   }
          # ------------------------------------------------------------------

          def round_state
            super.merge(shell_ipo: nil)
          end

          def description = 'Shell IPO After Swap'

          def active? = !!@round.shell_ipo

          def corporation = @round.shell_ipo && @round.shell_ipo[:corp]
          def starter     = @round.shell_ipo && @round.shell_ipo[:starter]
          def phase       = @round.shell_ipo && (@round.shell_ipo[:phase] || :starter)
          def remaining_for_starter = (@round.shell_ipo && @round.shell_ipo[:remaining]) || 0

          # ------------------------------------------------------------------
          # Turn ownership within the step
          # ------------------------------------------------------------------

          def players_in_others_phase
            @game.players.rotate(@game.players.index(starter)).drop(1)
          end

          def current_other
            players_in_others_phase[@round.shell_ipo[:cursor]]
          end

          def active_entities
            return [] unless active?

            phase == :starter ? [starter] : [current_other].compact
          end

          def current_entity
            active_entities.first
          end

          # ------------------------------------------------------------------
          # UI wiring
          # ------------------------------------------------------------------

          def visible_corporations
            corporation ? [corporation] : []
          end

          def issuable_shares
            []
          end

          def help
            return '' unless active?
            return '' unless corporation

            if phase == :starter
              "#{starter.name} may buy up to three shares of #{corporation.name} from the IPO or pass"
            else
              buyer = current_other
              "#{buyer.name} may buy one share of #{corporation.name} from the IPO or pass"
            end
          end

          # Always allow pass; only show buy if a buy is actually possible
          def actions(entity)
            return [] unless active?
            return [] unless entity == current_entity

            acts = []
            acts << 'buy_shares' if can_buy_any?(entity)
            acts << 'pass'
            acts
          end

          # Auto-pass a player who has no legal buy
          def auto_actions(entity)
            return nil unless active?
            return nil unless entity == current_entity
            return nil if can_buy_any?(entity)

            [Engine::Action::Pass.new(entity)]
          end

          # ------------------------------------------------------------------
          # Buy constraints
          # ------------------------------------------------------------------

          def find_buyable_share_for(entity)
            return nil unless corporation

            ipo_shares = corporation.shares.select { |s| s.buyable && s.owner == corporation }

            if phase == :starter
              return nil unless entity == starter
              return nil if remaining_for_starter <= 0

              ipo_shares.find { |s| s.percent <= remaining_for_starter }
            else
              return nil if entity == starter
              return nil if acted_others?(entity)

              ipo_shares.find { |s| s.percent == 10 }
            end
          end

          def can_buy_any?(entity)
            share = find_buyable_share_for(entity)
            return false unless share

            bundle = share.to_bundle
            entity.cash >= bundle.price
          end

          def can_buy?(entity, bundle)
            return false unless active?
            return false unless bundle
            return false unless entity.player?
            return false unless corporation
            return false unless bundle.corporation == corporation
            return false unless bundle.owner == corporation
            return false unless bundle.buyable

            if phase == :starter
              return false unless entity == starter
              return false if remaining_for_starter <= 0
              return false if bundle.common_percent > remaining_for_starter
            else
              return false if entity == starter
              return false if acted_others?(entity)
              return false unless bundle.common_percent == 10
            end

            entity.cash >= bundle.price
          end

          # ------------------------------------------------------------------
          # Action handlers
          # ------------------------------------------------------------------

          def process_buy_shares(action)
            player = action.entity
            bundle = action.bundle

            unless bundle
              share = find_buyable_share_for(player)
              raise GameError, 'No buyable share available' unless share

              bundle = share.to_bundle
            end

            raise GameError, 'Purchase not allowed' unless can_buy?(player, bundle)

            buy_shares(player, bundle)

            if phase == :starter
              @round.shell_ipo[:remaining] -= bundle.common_percent
              start_others_phase! if remaining_for_starter <= 0 || !can_buy_any?(starter)
            else
              mark_acted_other!(player)
              advance_cursor!
            end

            maybe_finish_or_continue!
          end

          def process_pass(action)
            player = action.entity
            log_pass(player)

            if phase == :starter
              start_others_phase!
            else
              mark_acted_other!(player)
              advance_cursor!
            end

            maybe_finish_or_continue!
          end

          def log_pass(entity)
            @log << if can_buy_any?(entity)
                      "#{entity.name} declines to buy shares"
                    else
                      "#{entity.name} has no valid actions and passes"
                    end
          end

          # ------------------------------------------------------------------
          # Phase/flow helpers
          # ------------------------------------------------------------------

          def acted_others?(player)
            (@round.shell_ipo[:acted] || {}).key?(player)
          end

          def mark_acted_other!(player)
            @round.shell_ipo[:acted] ||= {}
            @round.shell_ipo[:acted][player] = true
          end

          def advance_cursor!
            @round.shell_ipo[:cursor] += 1
          end

          def start_others_phase!
            @round.shell_ipo[:phase]  = :others
            @round.shell_ipo[:cursor] = 0
            @round.shell_ipo[:acted]  ||= {}
          end

          def others_done?
            cur = @round.shell_ipo[:cursor]
            cur >= players_in_others_phase.size || corporation.shares.none?(&:buyable)
          end

          def maybe_finish_or_continue!
            done =
              if phase == :starter
                remaining_for_starter <= 0 || !can_buy_any?(starter)
              else
                others_done?
              end
            @round.shell_ipo = nil if done
            @round.clear_cache!
          end
        end
      end
    end
  end
end
