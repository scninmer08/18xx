# frozen_string_literal: true

require_relative '../../../round/draft'

module Engine
  module Game
    module G18IL
      module Round
        class Draft < Engine::Round::Draft
          def self.short_name
            'DR'
          end

          def name
            'Private Draft Round'
          end

          def initialize(game, steps, **opts)
            super(game, steps, snake_order: true, **opts)
          end

          def next_entity!
            next_entity_index!
          end
        end
      end
    end
  end
end
