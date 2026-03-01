# frozen_string_literal: true

require_relative '../../../step/dividend'

module Engine
  module Game
    module G18FLOOD
      module Step
        class Dividend < Engine::Step::Dividend
          def actions(entity)
            return [] if entity.company?

            return ACTIONS if @game.shell_corporation?(entity)

            if @game.national_corporation?(entity)
              return total_revenue.zero? ? [] : ACTIONS
            end

            super
          end

          def auto_actions(entity)
            return [] unless entity == current_entity

            return [Engine::Action::Dividend.new(entity, kind: 'payout')]   if @game.shell_corporation?(entity)
            return [Engine::Action::Dividend.new(entity, kind: 'withhold')] if @game.national_corporation?(entity)

            []
          end

          def dividend_types
            ent = current_entity
            return [:payout]   if @game.shell_corporation?(ent)
            return [:withhold] if @game.national_corporation?(ent)

            super
          end

          def share_price_change(entity, revenue = 0)
            return {} if @game.national_corporation?(entity)
            return {} if @game.shell_corporation?(entity) && entity.trains.none?
            return { share_direction: :left, share_times: 1 } if revenue.zero?

            { share_direction: :right, share_times: 1 }
          end

          def skip!
            ent  = current_entity
            kind = @game.shell_corporation?(ent) ? 'payout' : 'withhold'
            action    = Engine::Action::Dividend.new(ent, kind: kind)
            action.id = @game.actions.last.id if @game.actions.last
            process_dividend(action)
          end

          def process_dividend(action)
            super
            return unless @game.center_used

            @game.center_contribute!(@game.center_phase_contribution)
            @game.maybe_auto_upgrade_center!
            @game.center_used = nil
          end
        end
      end
    end
  end
end
