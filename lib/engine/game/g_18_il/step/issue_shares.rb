# frozen_string_literal: true

require_relative '../../../step/issue_shares'

module Engine
  module Game
    module G18IL
      module Step
        class IssueShares < Engine::Step::IssueShares
          def round_state
            super.merge(
              {
                sp_issue_toggle: Hash.new(false),
              }
            )
          end

          def actions(entity)
            return [] if @game.last_set

            if entity.company? &&
               entity == @game.share_premium &&
               entity.owner == current_entity &&
               issuable_share_available(current_entity) &&
               !@game.intro_game? &&
               !@game.sp_used.equal?(entity)
              return ['choose_ability']
            end

            return [] unless entity == current_entity
            return [] if entity == @game.ic

            acts = []
            acts << 'sell_shares' if issuable_share_available(entity)
            acts << 'pass' unless acts.empty?
            acts
          end

          def description
            'Issue a Share'
          end

          def setup
            super
            @issued = nil
            @bought = nil
          end

          def issuable_share_available(entity)
            return false if issuable_shares(entity).empty?
            return false if @issued
            return true  if @game.intro_game?
            return false if @game.sp_used == @game.share_premium&.owner

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

          def actions_for(entity)
            actions(entity)
          end

          def choices_ability(company)
            return {} unless company == @game.share_premium

            corp = current_entity
            return {} if @round.sp_issue_toggle[corp]

            {
              'sp_on' => "Enable Share Premium (issue at #{@game.format_currency(corp.share_price.price * 2)})",
            }
          end

          def process_choose_ability(action)
            company = action.entity
            return unless company == @game.share_premium

            corp = current_entity
            return unless action.choice == 'sp_on'

            @round.sp_issue_toggle[corp] = true
            @log << "#{corp.name} can issue at double current price (#{company.name})"
            @game.reserved_share.buyable = true if @game.reserved_share
          end

          def process_sell_shares(action)
            corp = action.entity
            old_price = corp.share_price.price

            @game.sell_shares_and_change_price(
              action.bundle,
              allow_president_change: false,
              swap: nil,
              movement: :left_share
            )

            new_price = corp.share_price.price
            @log << "#{corp.name}'s share price moves left from #{@game.format_currency(old_price)} "\
                    "to #{@game.format_currency(new_price)}"

            if @round.sp_issue_toggle[corp]
              sp = @game.share_premium
              if sp&.owner == corp
                @game.sp_used = sp
                sp.close!
                @log << "#{sp.name} (#{corp.name}) closes"
              end
              @round.sp_issue_toggle[corp] = false
            end

            @issued = true
          end

          def can_sell?(entity, bundle)
            return false unless bundle

            bundle.owner == entity &&
              bundle.corporation == entity &&
              bundle.num_shares == 1 &&
              !@issued
          end

          def log_pass(entity)
            @log << "#{entity.name} passes #{description.downcase}"
          end
        end
      end
    end
  end
end
