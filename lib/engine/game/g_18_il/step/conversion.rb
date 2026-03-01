# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../token'

module Engine
  module Game
    module G18IL
      module Step
        class Conversion < Engine::Step::Base
          def actions(entity)
            return [] if @game.last_set
            return [] if !entity.corporation? || entity != current_entity || entity == @round.converts[-1]

            actions = []
            actions << 'convert' if [2, 5].include?(entity.total_shares)
            actions << 'pass' if actions.any?
            actions
          end

          def description
            'Convert'
          end

          def help
            [
              "Convert #{current_entity.name} to a #{current_entity.total_shares == 2 ? '5' : '10'}-share corporation or pass:",
            ]
          end

          def others_acted?
            !@round.converts.empty?
          end

          def process_convert(action)
            corporation = action.entity

            if corporation.share_price.price < 40
              raise GameError, "#{corporation.name} cannot convert when its share price is below #{@game.format_currency(40)}"
            end

            before = corporation.total_shares

            @game.convert(corporation)

            after = corporation.total_shares
            @log << "#{corporation.name} converts from a #{before}-share to a #{after}-share corporation"
            @round.converts << corporation
            @round.converted = corporation
          end

          def show_other_players
            false
          end

          def round_state
            {
              converted: nil,
              converts: [],
            }
          end
        end
      end
    end
  end
end
