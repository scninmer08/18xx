# frozen_string_literal: true

require_relative '../../../step/dividend'
require_relative '../../../step/half_pay'

module Engine
  module Game
    module G18IL
      module Step
        class Dividend < Engine::Step::Dividend
          include Engine::Step::HalfPay

          DIVIDEND_TYPES = %i[payout half withhold].freeze

          def setup
            if @game.frozen_corporations.include?(current_entity)
              @log << "#{current_entity.name} is frozen with a loan of " \
                      "#{@game.format_currency(current_entity.loans.first.amount)}"
            end
            super
          end

          def actions(entity)
            return [] if @game.last_set
            return [] unless entity == current_entity
            return [] if entity == @game.ic && @game.ic_in_receivership?

            super
          end

          def dividend_types
            return [:payout] if @game.last_set
            return [:withhold] if current_entity == @game.ic && @game.ic_in_receivership?

            DIVIDEND_TYPES
          end

          def half_pay_withhold_amount(entity, revenue)
            return super unless entity.total_shares == 10

            (revenue / 2 / 10).to_i * 10
          end

          def share_price_change(entity, revenue = 0)
            return {} if @game.frozen_corporations.include?(entity)
            return {} if entity == @game.ic && @game.ic_in_receivership?

            price = entity.share_price.price
            return { share_direction: :down, share_times: 1 } if revenue.zero? && price == @game.lowest_stock_price
            return { share_direction: :left, share_times: 1 } if revenue.zero?
            return { share_direction: :up, share_times: 1 } if revenue < price
            return { share_direction: :right, share_times: 1 } if revenue < price * 2
            return { share_direction: :right, share_times: 2 } if revenue < price * 3

            { share_direction: :right, share_times: 3 }
          end

          def log_run_payout(entity, kind, revenue, subsidy, action, payout)
            unless Dividend::DIVIDEND_TYPES.include?(kind)
              @log << "#{entity.name} runs for #{@game.format_currency(revenue)} and pays #{action.kind}"
            end

            if payout[:corporation].positive?
              @log << "#{entity.name} withholds #{@game.format_currency(payout[:corporation])}"
            elsif payout[:per_share].zero?
              @log << "#{entity.name} does not run"
            end
            @log << "#{entity.name} earns a #{@game.subsidy_name} of #{@game.format_currency(subsidy)}" if subsidy.positive?
          end

          def dividend_options(entity)
            revenue = total_revenue
            dividend_types.to_h do |type|
              payout = send(type, entity, revenue)
              # Shares remaining in the Auction Pool do not pay dividends to IC.
              payout[:divs_to_corporation] = entity == @game.ic ? 0 : corporation_dividends(entity, payout[:per_share])
              [type, payout.merge(share_price_change(entity, revenue - payout[:corporation]))]
            end
          end

          def process_dividend(action)
            super
            @game.payoff_loan(action.entity) unless action.entity.loans.empty?
          end

          def payout_shares(entity, revenue)
            per_share = payout_per_share(entity, revenue)

            payouts = {}
            (@game.players + @game.corporations).each do |payee|
              # Shares remaining in the Auction Pool do not pay dividends to IC.
              next if payee == @game.ic && entity == @game.ic

              payout_entity(entity, payee, per_share, payouts)
            end

            receivers = payouts
                          .sort_by { |_r, c| -c }
                          .map { |receiver, cash| "#{@game.format_currency(cash)} to #{receiver.name}" }.join(', ')

            log_payout_shares(entity, revenue, per_share, receivers)
          end

          def payout_entity(entity, holder, per_share, payouts)
            super
            @game.payoff_loan(holder) if holder.corporation? && holder.loans.any? && holder.cash.positive?
          end

          def skip!
            return unless current_entity
            return super unless @game.last_set

            process_dividend(Action::Dividend.new(
              current_entity,
              kind: dividend_types.first.to_s,
            ))

            return unless current_entity.receivership?
            return if current_entity.trains.any?
            return if current_entity.share_price.price.zero?

            @log << "#{current_entity.name} is in receivership and does not own a train."
            share_price_change(current_entity)
          end
        end
      end
    end
  end
end
