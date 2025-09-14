# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G18IL
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        PROTOTYPE = true

        GAME_SUBTITLE = 'The Formation of the Illinois Central Railroad'
        GAME_DESIGNER = 'Scott Ninmer'
        GAME_PUBLISHER = :self_published
        GAME_LOCATION = 'Illinois, USA'
        GAME_RULES_URL = 'https://www.dropbox.com/scl/fi/trlhkdpujpu4w4m34g66i/18IL_Rulebook_v0.8.4.pdf?rlkey=c8xnalp4h7212hyvba96lpza6&dl=0'
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18IL'
        PLAYER_RANGE = [2, 6].freeze

        OPTIONAL_RULES = [
          {
            sym: :intro_game,
            short_name: 'Introductory Game',
            desc: 'Private companies are not used. The #G1 tile begins the game on the Galena (C2) hex.',
          },
          {
            sym: :fixed_setup,
            short_name: 'Fixed Setup',
            desc: 'Private companies are assigned to corporations deterministically.',
          },
          {
            sym: :lots_variant,
            short_name: '(2p only) Lots Variant',
            desc: 'Two lots consisting of one 10-share, two 5-share, and one 2-share concessions are formed '\
                  'for the first concession round.',
          },
          { sym: :_sep1, short_name: '', desc: '' },
          { sym: :_separator_trains, short_name: '--- Optional Train Tweaks ---', desc: '' },

          {
            sym: :one_extra_three_train,
            short_name: '+1 3-Train',
            desc: 'Adds one additional 3-train to the train roster.',
          },
          {
            sym: :two_extra_three_trains,
            short_name: '+2 3-Trains',
            desc: 'Adds two additional 3-trains to the train roster.',
          },
          { sym: :_sep2, short_name: '', desc: '' },
          {
            sym: :one_extra_four_train,
            short_name: '+1 4-/3P Train',
            desc: 'Adds one additional 4-/3P train to the train roster.',
          },
          {
            sym: :two_extra_four_trains,
            short_name: '+2 4-/3P Trains',
            desc: 'Adds two additional 4-/3P trains to the train roster.',
          },
          { sym: :_sep3, short_name: '', desc: '' },
          {
            sym: :one_extra_four_plus_two_p_train,
            short_name: '+1 4+2P Train',
            desc: 'Adds one additional 4+2P train to the train roster.',
          },
          {
            sym: :two_extra_four_plus_two_p_trains,
            short_name: '+2 4+2P Trains',
            desc: 'Adds two additional 4+2P trains to the train roster.',
          },
          { sym: :_sep4, short_name: '', desc: '' },
          {
            sym: :one_extra_five_plus_one_p_train,
            short_name: '+1 5+1P Train',
            desc: 'Adds one additional 5+1P train to the train roster.',
          },
          {
            sym: :two_extra_five_plus_one_p_trains,
            short_name: '+2 5+1P Trains',
            desc: 'Adds two additional 5+1P trains to the train roster.',
          },
          { sym: :_sep5, short_name: '', desc: '' },
          {
            sym: :one_extra_six_train,
            short_name: '+1 6-Train',
            desc: 'Adds one additional 6-train to the train roster.',
          },
          {
            sym: :two_extra_six_trains,
            short_name: '+2 6-Trains',
            desc: 'Adds two additional 6-trains to the train roster.',
          },
        ].freeze
      end
    end
  end
end
