# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G18FLOOD
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        PROTOTYPE = true

        # GAME_SUBTITLE = ''
        GAME_DESIGNER = 'Scott Ninmer'
        GAME_PUBLISHER = :self_published
        # GAME_LOCATION = ''
        GAME_RULES_URL = 'https://www.dropbox.com/scl/fi/xlv804oxxj1khy1ufj0yf/18FLOOD_Rulebook_v0.1.0.pdf?rlkey=14pdiuy2r4dhv4717q32hhblv&dl=0'
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18FLOOD'
        PLAYER_RANGE = [3, 3].freeze

        OPTIONAL_RULES = [].freeze
      end
    end
  end
end
