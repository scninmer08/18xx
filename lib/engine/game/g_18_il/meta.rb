# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G18IL
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha

        GAME_SUBTITLE = 'The Formation of the Illinois Central Railroad'
        GAME_DESIGNER = 'Scott Ninmer'
        GAME_PUBLISHER = :self_published
        GAME_LOCATION = 'Illinois, USA'
        GAME_RULES_URL = 'https://www.dropbox.com/scl/fi/2vh3slq5cb42ucsl44v5r/18IL_Rulebook_v0.9.2.pdf?rlkey=2wq9h8kvcwih4px3ftbus77qe&dl=0'
        GAME_INFO_URL = 'https://github.com/tobymao/18xx/wiki/18IL'
        PLAYER_RANGE = [2, 6].freeze

        # GAME_VARIANTS = [
        #   {
        #     sym: :solo,
        #     name: 'Solo',
        #     title: '18IL Solo',
        #     desc: 'Play against the Pullman bot!',
        #   },
        # ].freeze

        OPTIONAL_RULES = [
        # { sym: :_sep, short_name: '', desc: '' },
        {
          sym: :intro_game,
          short_name: 'Introductory Game',
          desc: 'Private companies are not used.',
        },
        {
          sym: :draft_variant,
          short_name: 'Private Draft Variant',
          desc: 'Players snake-draft private companies from the full pool. Undrafted privates enter the development pool. '\
                'Drafted privates may be assigned when starting or converting corporations.',
        },
        {
          sym: :full_draft_variant,
          short_name: 'Full Draft Variant',
          desc: 'Players snake-draft concessions and private companies from the full pool. Undrafted concessions enter the '\
                'auction pool and undrafted privates enter the development pool. Drafted privates may be assigned when '\
                'starting or converting corporations.',
        },
          # { sym: :_sep1, short_name: '', desc: '' },
          # { sym: :_separator_trains, short_name: '--- Optional Train Tweaks ---', desc: '' },
          # {
          #   sym: :one_extra_three_train,
          #   short_name: '+1 3-Train',
          #   desc: 'Adds one additional 3-train to the train roster.',
          # },
          # {
          #   sym: :two_extra_three_trains,
          #   short_name: '+2 3-Trains',
          #   desc: 'Adds two additional 3-trains to the train roster.',
          # },
          # { sym: :_sep2, short_name: '', desc: '' },
          # {
          #   sym: :one_extra_four_train,
          #   short_name: '+1 4-/0+3C Train',
          #   desc: 'Adds one additional 4-/0+3C train to the train roster.',
          # },
          # {
          #   sym: :two_extra_four_trains,
          #   short_name: '+2 4-/0+3C Trains',
          #   desc: 'Adds two additional 4-/0+3C trains to the train roster.',
          # },
          # { sym: :_sep3, short_name: '', desc: '' },
          # {
          #   sym: :one_extra_four_plus_two_p_train,
          #   short_name: '+1 4+2C Train',
          #   desc: 'Adds one additional 4+2C train to the train roster.',
          # },
          # {
          #   sym: :two_extra_four_plus_two_p_trains,
          #   short_name: '+2 4+2C Trains',
          #   desc: 'Adds two additional 4+2C trains to the train roster.',
          # },
          # { sym: :_sep4, short_name: '', desc: '' },
          # {
          #   sym: :one_extra_five_plus_one_p_train,
          #   short_name: '+1 5+1C Train',
          #   desc: 'Adds one additional 5+1C train to the train roster.',
          # },
          # {
          #   sym: :two_extra_five_plus_one_p_trains,
          #   short_name: '+2 5+1C Trains',
          #   desc: 'Adds two additional 5+1C trains to the train roster.',
          # },
          # { sym: :_sep5, short_name: '', desc: '' },
          # {
          #   sym: :one_extra_six_train,
          #   short_name: '+1 6-Train',
          #   desc: 'Adds one additional 6-train to the train roster.',
          # },
          # {
          #   sym: :two_extra_six_trains,
          #   short_name: '+2 6-Trains',
          #   desc: 'Adds two additional 6-trains to the train roster.',
          # },
        ].freeze
      end
    end
  end
end
