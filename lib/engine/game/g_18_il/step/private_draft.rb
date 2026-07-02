# frozen_string_literal: true

require_relative 'draft_private'

module Engine
  module Game
    module G18IL
      module Step
        class PrivateDraft < DraftPrivate
          def draft_cap
            case @game.players.count
            when 2 then 4
            when 3, 4 then 2
            else 1
            end
          end
        end
      end
    end
  end
end
