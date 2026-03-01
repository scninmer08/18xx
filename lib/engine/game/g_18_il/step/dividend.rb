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
            if @game.insolvent_corporations.include?(current_entity)
              @log << "#{current_entity.name} has a loan of #{@game.format_currency(current_entity.loans.first.amount)}"\
                      ' and must withhold during the dividend step'
            end
            super
          end

          def actions(entity)
            return [] if @game.last_set
            return [] unless entity == current_entity

            super
          end

          def dividend_types
            return [:withhold] if (current_entity == @game.ic && @game.ic_in_receivership?) ||
                                   !current_entity.loans.empty? || @game.train_borrowed

            return [:payout] if @game.last_set

            DIVIDEND_TYPES
          end

          def share_price_change(entity, revenue = 0)
            price = entity.share_price.price
            return { share_direction: :down, share_times: 1 } if revenue.zero? && price == @game.lowest_stock_price
            return { share_direction: :left, share_times: 1 } if revenue.zero?
            return { share_direction: :down, share_times: 1 } if revenue < price / 2
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
              @log << if @game.train_borrowed
                        "#{entity.name} withholds #{@game.format_currency(payout[:corporation])} "\
                          "(#{@game.format_currency(payout[:corporation])} paid to bank as a lease payment)"
                      else
                        "#{entity.name} withholds #{@game.format_currency(payout[:corporation])}"
                      end
            elsif payout[:per_share].zero?
              @log << "#{entity.name} does not run"
            end
            @log << "#{entity.name} earns a #{@game.subsidy_name} of #{@game.format_currency(subsidy)}" if subsidy.positive?
            @game.train_borrowed = nil
            return unless (borrowed_train = @game.borrowed_trains[current_entity])

            @game.log << "#{current_entity.name} returns a #{borrowed_train.name} train"
            @game.remove_train(borrowed_train)
            @game.depot.unshift_train(borrowed_train)
            @game.borrowed_trains[current_entity] = nil
          end

          def dividend_options(entity)
            revenue = total_revenue
            revenue = total_revenue / 2 if @game.train_borrowed
            dividend_types.to_h do |type|
              payout = send(type, entity, revenue)
              payout[:divs_to_corporation] = corporation_dividends(entity, payout[:per_share])
              # shares remaining in concession auction do not pay to IC
              payout[:divs_to_corporation] = 0 if entity == @game.ic
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
              # shares remaining in concession auction do not pay to IC
              next if payee == @game.ic && entity == @game.ic

              payout_entity(entity, payee, per_share, payouts)
            end

            receivers = payouts
                          .sort_by { |_r, c| -c }
                          .map { |receiver, cash| "#{@game.format_currency(cash)} to #{receiver.name}" }.join(', ')

            log_payout_shares(entity, revenue, per_share, receivers)
          end

          def skip!
            return super unless @game.last_set

            revenue = @game.routes_revenue(routes)
            process_dividend(Action::Dividend.new(
              current_entity,
              kind: revenue.positive? ? 'payout' : 'withhold',
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
