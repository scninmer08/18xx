# frozen_string_literal: true

require_relative '../../g_18_il/step/dividend'

module Engine
  module Game
    module G18IlSolo
      module Step
        class Dividend < G18IL::Step::Dividend
          def dividend_types
            return [:withhold] if @game.train_borrowed && !@game.last_set

            return [:payout] if @game.last_set || current_entity.owner == @game.robot

            DIVIDEND_TYPES
          end

          def payout_shares(entity, revenue)
            per_share = payout_per_share(entity, revenue)

            payouts = {}

            # Pay everyone except Robot using the normal helper
            (@game.players + @game.corporations).each do |payee|
              next if payee == @game.robot

              payout_entity(entity, payee, per_share, payouts)
            end

            # Redirect Robot’s payout to IC (computed off Robot’s actual share count)
            robot_shares = @game.robot.num_shares_of(entity, ceil: false)
            if robot_shares.positive? && per_share.positive?
              amount = robot_shares * per_share
              @game.bank.spend(amount, @game.ic)
              payouts[@game.ic] = (payouts[@game.ic] || 0) + amount
            end

            receivers = payouts
                          .sort_by { |_r, c| -c }
                          .map { |receiver, cash| "#{@game.format_currency(cash)} to #{receiver.name}" }
                          .join(', ')

            log_payout_shares(entity, revenue, per_share, receivers)
          end
        end
      end
    end
  end
end
