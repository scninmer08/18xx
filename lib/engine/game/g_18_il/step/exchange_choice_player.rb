# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class ExchangeChoicePlayer < Engine::Step::Base
          def actions(entity)
            return [] unless entity == current_entity

            ['choose']
          end

          def active_entities
            return [] unless @game.exchange_choice_player

            [@game.exchange_choice_player]
          end

          def description
            "Sell or Exchange President's Share"
          end

          def active?
            !active_entities.empty?
          end

          def choice_available?(entity)
            entity == @game.exchange_choice_player
          end

          def choices
            ic = @game.ic
            choices = []
            choices << ["Sell for #{@game.format_currency(@game.merged_corporation.share_price.price)}"]
            choices << ["Exchange for 10% share of #{ic.name}"] unless ic.shares_of(ic).last == ic.shares_of(ic).first
            choices
          end

          def choice_name
            "President's Share Decision"
          end

          def process_choose(action)
            player = action.entity

            if action.choice == "Exchange for 10% share of #{@game.ic.name}"
              @game.presidency_exchange(player)
            else
              @game.presidency_sell(player)
            end

            @game.exchange_choice_player = nil

            # Continue the merge flow
            @game.merge_corporation_part_two

            # If formation was pending, and there are no more choices, finish now
            @game.finalize_ic_formation_if_ready!
          end
        end
      end
    end
  end
end
