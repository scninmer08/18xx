# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G1872
      module Step
        class BuyTokens < Engine::Step::Base
          def actions(entity)
            entity == pending_corporation ? ['choose'] : []
          end

          def auto_actions(entity)
            return [] unless entity == pending_corporation

            [Engine::Action::Choose.new(entity, choice: '1')]
          end

          def active_entities
            pending_corporation ? [pending_corporation] : []
          end

          def choice_available?(entity)
            entity == pending_corporation
          end

          def visible_corporations
            [pending_corporation].compact
          end

          def ipo_type(_corporation); end

          def description
            'Buy Starting Station Markers'
          end

          def choice_name
            "#{pending_corporation.name} buys one additional station marker"
          end

          def choices
            { '1' => "1 (#{@game.format_currency(@game.class::TOKEN_PRICE)})" }
          end

          def process_choose(action)
            raise GameError, 'That marker count is not available' unless choices.key?(action.choice)

            corporation = pending_corporation
            @game.purchase_starting_tokens(corporation)
            @game.pending_token_buys.shift
            pass!
          end

          private

          def pending_corporation
            @game.pending_token_buys.first
          end
        end
      end
    end
  end
end
