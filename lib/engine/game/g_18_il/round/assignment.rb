# frozen_string_literal: true

require_relative '../../../round/draft'

module Engine
  module Game
    module G18IL
      module Round
        class Assignment < Engine::Round::Draft
          def self.short_name
            'AS'
          end

          def name
            'Private Assignment Round'
          end

          def select_entities
            @game.players
          end

          def next_entity!
            next_entity_index!
          end
        end
      end
    end
  end
end
