# frozen_string_literal: true

require_relative 'issue_shares'

module Engine
  module Game
    module G18IL
      module Step
        class SpecialIssueShares < IssueShares
          ACTIONS = %w[sell_shares].freeze

          def description
            "Use #{@game.share_premium&.name} ability"
          end

          def actions(entity)
            actions = []
            return actions if @game.last_set
            return actions unless entity.corporation?
            return actions unless entity == current_entity

            actions << 'sell_shares' unless issuable_shares(entity).empty?
            actions << 'pass' if blocks? && !actions.empty?

            actions
          end

          # def visible_corporations
          #   [current_entity]
          # end

          def active_entities
            return [] unless @game.share_premium&.owner == @round.current_operator

            [@game.share_premium&.owner].compact
          end

          def pass_description
            'Pass (Share Premium Issue)'
          end

          def help
            return [] unless active?

            [
              'Use Share Premium to issue a share at double the current share price:',
            ]
          end

          def issuable_shares(entity)
            # Done via Sell Shares
            @game.issuable_shares(entity)
          end

          def process_pass(action)
            log_pass(action.entity)
            pass!
          end

          def process_sell_shares(action)
            @game.sp_used = action.entity
            @game.reserved_share.buyable = true if @game.reserved_share
            old_price = action.bundle.corporation.share_price.price
            @game.sell_shares_and_change_price(action.bundle, allow_president_change: false, swap: nil, movement: :left_share)
            new_price = action.bundle.corporation.share_price.price
            @log << "#{action.bundle.corporation.name}'s share price moves left horizontally "\
                    "from #{@game.format_currency(old_price)} to #{@game.format_currency(new_price)}"
            pass!
          end

          def ability(entity, share: nil)
            return unless entity&.company?

            @game.abilities(entity, :description, time: ability_timing) do |ability|
              return ability unless share
            end

            nil
          end
        end
      end
    end
  end
end
