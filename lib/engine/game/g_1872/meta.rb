# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G1872
      module Meta
        include Game::Meta

        DEV_STAGE = :alpha
        PROTOTYPE = true

        GAME_TITLE = '1872'
        GAME_SUBTITLE = 'The High Plains'
        GAME_DESIGNER = 'Scott Ninmer'
        GAME_RULES_URL = 'https://www.dropbox.com/scl/fi/ebqf8acw4q2qlvdqxrz8g/'\
                         '1872_The_High_Plains_Rulebook_v.0.1.0.pdf?'\
                         'rlkey=vyy7qhsdtwfgoyabd5k1f3qe9&dl=0'

        PLAYER_RANGE = [3, 5].freeze

        OPTIONAL_RULES = [
          {
            sym: :hostile_takeover_variant,
            short_name: 'Hostile Takeover Variant',
            desc: 'Adds the inter-corporation acquisition corporate action.',
          },
          {
            sym: :genealogy_company_purchases,
            short_name: 'Genealogy Company Purchases',
            desc: 'Allows corporations to buy private companies from other corporations in their genealogy.',
          },
        ].freeze
      end
    end
  end
end
