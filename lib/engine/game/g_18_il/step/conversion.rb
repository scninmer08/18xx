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
            return [] if @round.private_choice_corporation == entity

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
            before = corporation.total_shares

            @game.convert(corporation)

            after = corporation.total_shares
            @log << "#{corporation.name} converts from a #{before}-share to a #{after}-share corporation"
            @round.converts << corporation
            @round.converted = corporation
          end

          def process_pass(action)
            corporation = action.entity
            queue_private_choice(corporation)
            super
          end

          def skip!
            queue_private_choice(current_entity)
            super
          end

          def show_other_players
            false
          end

          def round_state
            {
              converted: nil,
              converts: [],
              private_choice_corporation: nil,
            }
          end

          private

          def queue_private_choice(corporation)
            return if !corporation&.corporation? || !corporation&.ipoed || corporation.closed? || corporation.total_shares <= 2
            return if @round.converted
            return if @round.converts.include?(corporation)
            return if @round.private_choice_corporation

            @round.private_choice_corporation = corporation
            @round.clear_cache!
          end
        end
      end
    end
  end
end
