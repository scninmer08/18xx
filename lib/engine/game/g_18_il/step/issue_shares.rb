# frozen_string_literal: true

require_relative '../../../step/issue_shares'

module Engine
  module Game
    module G18IL
      module Step
        class IssueShares < Engine::Step::IssueShares
          def actions(entity)
            return [] if @game.last_set
            return [] unless entity == current_entity
            return [] if entity == @game.ic

            actions = []
            actions << 'sell_shares' if issuable_share_available(entity)
            actions << 'pass' unless actions.empty?
            actions
          end

          def setup
            super
            @issued = nil
            @bought = nil
            @game.corporate_buy = nil
          end

          def description
            'Issue a Share'
          end

          def log_skip(entity)
            if !@game.intro_game? && @game.sp_used == @game.share_premium.owner
              @game.share_premium.close!
              @log << "#{@game.share_premium.name} (#{entity.name}) closes"
            else
              @log << "#{entity.name} skips #{description.downcase}"
            end
          end

          def issuable_share_available(entity)
            return false if issuable_shares(entity).empty?
            return false if @issued
            return true if @game.intro_game?
            return false if @game.sp_used == @game.share_premium.owner

            true
          end

          def redeemable_shares(_entity)
            []
          end

          def pass_description
            'Pass (Issue)'
          end

          def issuable_shares(entity)
            # Done via Sell Shares
            @game.issuable_shares(entity)
          end

          def process_sell_shares(action)
            old_price = action.entity.share_price.price
            @game.sell_shares_and_change_price(action.bundle, allow_president_change: false, swap: nil, movement: :left_share)
            new_price = action.entity.share_price.price
            @log << "#{action.entity.name}'s share price moves left from #{@game.format_currency(old_price)} to "\
                    "#{@game.format_currency(new_price)}"
            @issued = true
          end

          def can_sell?(entity, bundle)
            return unless bundle
            return true if bundle.owner == entity && bundle.corporation == entity && bundle.num_shares == 1 && !@issued

            false
          end

          def log_pass(entity)
            @log << "#{entity.name} passes #{description.downcase}"
          end

          def process_pass(action)
            log_pass(action.entity)
            if !@game.intro_game? && @game.sp_used == @game.share_premium.owner
              @game.share_premium.close!
              @log << "#{@game.share_premium.name} (#{action.entity.name}) closes"
            end
            pass!
          end
        end
      end
    end
  end
end
