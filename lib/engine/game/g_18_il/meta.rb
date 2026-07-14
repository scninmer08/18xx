# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module G18IL
      module Meta
        include Game::Meta

        DEV_STAGE = :alpha

        GAME_SUBTITLE = 'The Formation of the Illinois Central Railroad'
        GAME_DESIGNER = 'Scott Ninmer'
        GAME_PUBLISHER = :self_published
        GAME_LOCATION = 'Illinois, USA'
        GAME_RULES_URL = 'https://www.dropbox.com/scl/fi/wion4zpk8cnal42zug7s1/18IL_Rulebook_v0.9.7.pdf?rlkey=difgkx3nh4mwk5z2ciy52tat7&dl=0'
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
          sym: :packet_auction_variant,
          short_name: 'Packet Auction Variant (2-4p only)',
          desc: 'Players bid for the right to choose a packet. Packets contain randomly selected concessions and '\
                'private companies. With three players, the unselected packet returns its concessions to the '\
                'Auction Pool and its private companies to the Development Pool.',
          players: [2, 3, 4],
        },
          # {
          #   sym: :draft_variant,
          #   short_name: 'Private Draft Variant',
          #   desc: 'Players snake-draft private companies from the full pool. Undrafted privates enter the Development Pool. '\
          #         'Drafted privates may be assigned when starting or converting corporations.',
          # },
          # {
          #   sym: :full_draft_variant,
          #   short_name: 'Full Draft Variant',
          #   desc: 'Players snake-draft concessions and private companies from the full pool. Undrafted concessions enter the '\
          #         'Auction Pool and undrafted privates enter the Development Pool. Drafted privates may be assigned when '\
          #         'starting or converting corporations.',
          # },
        ].freeze

        def self.check_options(options, _min_players, max_players)
          optional_rules = (options || []).map(&:to_sym)
          return unless optional_rules.include?(:packet_auction_variant) && max_players.to_i > 4

          { error: 'Packet Auction Variant is only available for 2-4 players' }
        end

        def self.max_players(optional_rules, _num_players)
          optional_rules&.map(&:to_sym)&.include?(:packet_auction_variant) ? 4 : PLAYER_RANGE[1]
        end
      end
    end
  end
end
