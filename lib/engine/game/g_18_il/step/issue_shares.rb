# frozen_string_literal: true

require_relative '../../../step/issue_shares'

module Engine
  module Game
    module G18IL
      module Step
        class IssueShares < Engine::Step::IssueShares
          def round_state
            super.merge(
              sp_issue_toggle: Hash.new(false),
            )
          end

          def setup
            super
            @issued = false
          end

          def description = 'Issue a Share'
          def pass_description = 'Pass (Issue)'
          def redeemable_shares(_entity) = []

          def actions(entity)
            return [] if @game.last_set

            if entity.company? &&
               entity == @game.company_by_id('SP') &&
               entity.owner == current_entity &&
               !@game.private_used?(entity) &&
               sp_issuable_share_available?(current_entity) &&
               !@game.intro_game? &&
               !@round.sp_issue_toggle[current_entity]
              return ['choose_ability']
            end

            # Only the current operating corporation can issue.
            return [] unless entity == current_entity
            return [] if entity == @game.ic

            acts = []
            acts << 'sell_shares' if issuable_share_available(entity)
            acts << 'pass' unless acts.empty?
            acts
          end

          def issuable_share_available(entity)
            return false if @issued
            return false if issuable_shares(entity).empty?

            true
          end

          def can_sell?(entity, bundle)
            return false unless bundle

            bundle.owner == entity &&
              bundle.corporation == entity &&
              bundle.num_shares == 1 &&
              !@issued
          end

          def issuable_shares(entity)
            shares = @game.issuable_shares(entity)
            return shares unless shares.empty?

            reserve = @game.reserved_share_for(entity)
            return [] unless reserve&.owner == entity
            return [] if @issued

            [ShareBundle.new(reserve)]
          end

          def choices_ability(company)
            return {} unless company == @game.company_by_id('SP')

            corp = current_entity
            return {} if @round.sp_issue_toggle[corp]
            return {} unless sp_issuable_share_available?(corp)

            {
              'sp_on' => 'Activate',
            }
          end

          def process_choose_ability(action)
            company = action.entity
            return unless company == @game.company_by_id('SP')
            return unless action.choice == 'sp_on'

            corp = current_entity
            @round.sp_issue_toggle[corp] = true
            @log << "#{corp.name} activates #{company.name}"
          end

          def sp_issuable_share_available?(corp)
            issuable_share_available(corp) || @game.reserved_share_for(corp)&.owner == corp
          end

          def process_sell_shares(action)
            corp = action.entity
            old_price = corp.share_price.price
            reserve = @game.reserved_share_for(corp)
            reserve.buyable = true if action.bundle.shares.include?(reserve)

            @game.sell_shares_and_change_price(
              action.bundle,
              allow_president_change: false,
              movement: :left_share,
            )

            new_price = corp.share_price.price
            @log << "#{corp.name}'s share price moves left from "\
                    "#{@game.format_currency(old_price)} to #{@game.format_currency(new_price)}"

            if @round.sp_issue_toggle[corp]
              if (sp = @game.company_by_id('SP'))&.owner == corp
                @game.flip_private!(sp)
              end
              @round.sp_issue_toggle[corp] = false
            end

            @issued = true
          end

          def log_pass(entity)
            @log << "#{entity.name} passes #{description.downcase}"
          end
        end
      end
    end
  end
end
