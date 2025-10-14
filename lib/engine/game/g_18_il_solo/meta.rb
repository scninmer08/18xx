# frozen_string_literal: true

require_relative '../meta'
require_relative '../g_18_il/meta'

module Engine
  module Game
    module G18IlSolo
      module Meta
        include Game::Meta
        include G18IL::Meta

        DEPENDS_ON = '18IL'

        DEV_STAGE = :prealpha

        GAME_IS_VARIANT_OF = G18IL::Meta
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18IL'.freeze
        GAME_RULES_URL = 'https://www.dropbox.com/scl/fi/0k88b27nsmhp46rr8z7ji/18IL_Solo_Rulebook_v0.1.0.pdf?rlkey=3h3vb25jhyd5nbk5njn5frj8z&dl=0'

        GAME_TITLE = '18IL Solo'.freeze

        PLAYER_RANGE = [1, 1].freeze
        OPTIONAL_RULES = [
          {
            sym: :very_easy,
            short_name: 'Very Easy',
            desc: 'Start with $560.',
          },
          {
            sym: :easy,
            short_name: 'Easy',
            desc: 'Start with $480.',
          },
          {
            sym: :normal,
            short_name: 'Normal',
            desc: 'Start with $400 (default).',
          },
          {
            sym: :difficult,
            short_name: 'Difficult',
            desc: 'Start with $320.',
          },
          {
            sym: :very_difficult,
            short_name: 'Very Difficult',
            desc: 'Start with $240.',
          },
        ].freeze
      end
    end
  end
end
