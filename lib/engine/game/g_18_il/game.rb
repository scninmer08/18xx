# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'
require_relative 'corporations'
require_relative 'companies'
require_relative 'map'
require_relative 'tiles'
require_relative 'trains'
require_relative 'market'
require_relative 'phases'
require_relative '../../loan'
require_relative '../cities_plus_towns_route_distance_str'

module Engine
  module Game
    module G18IL
      class Game < Game::Base
        include_meta(G18IL::Meta)
        include Corporations
        include Companies
        include Map
        include Tiles
        include Trains
        include Market
        include Phases
        include CitiesPlusTownsRouteDistanceStr

        attr_accessor :exchange_choice_player, :exchange_choice_corp, :train_borrowed, :will_buy_other_train,
                      :emr_active, :pending_rusting_event

        attr_reader :stl_nodes, :exchange_choice_corps, :borrowed_trains, :closed_corporations,
                    :last_set_pending, :lots, :lot_proxies, :lot_choice_proxy, :merged_corporation, :last_set,
                    :insolvent_corporations, :ic_trigger_entity

        TRACK_RESTRICTION = :permissive
        SELL_BUY_ORDER = :sell_buy
        TILE_RESERVATION_BLOCKS_OTHERS = :always
        CURRENCY_FORMAT_STR = '$%s'
        BANK_CASH = 99_999
        CAPITALIZATION = :incremental
        CERT_LIMIT = { 2 => 24, 3 => 18, 4 => 15, 5 => 13, 6 => 11 }.freeze
        STARTING_CASH = { 2 => 500, 3 => 420, 4 => 360, 5 => 320, 6 => 300 }.freeze
        TOKEN_COST = 40

        EVENTS_TEXT = Base::EVENTS_TEXT.merge(
          'signal_end_game' => ['Signal End Game', 'Game ends 3 ORs after purchase of first D train'],
        ).freeze

        STATUS_TEXT = Base::STATUS_TEXT.merge(
          'pullman_strike' => ['Pullman Strike (end of next OR)',
                               '4+2C and 5+1C trains are downgraded to 4- and 5-trains, respectively'],
          'cert_limit_change' => ['Cert Limit Change (end of next OR)',
                                  'Cert limit is reduced by 1 for each unopened corporation that is removed'],
        )

        POOL_SHARE_DROP = :down_share
        BANKRUPTCY_ALLOWED = false
        CERT_LIMIT_INCLUDES_PRIVATES = false
        MIN_BID_INCREMENT = 5
        MUST_BID_INCREMENT_MULTIPLE = true
        ONLY_HIGHEST_BID_COMMITTED = true

        TILE_LAYS = [
          { lay: true, upgrade: true, cost: 0 },
          { lay: true, upgrade: :not_if_upgraded, cost: 20, cannot_reuse_same_hex: true },
        ].freeze

        HOME_TOKEN_TIMING = :float
        MUST_BUY_TRAIN = :always
        DISCARDED_TRAINS = :remove

        GAME_END_CHECK = {
          final_phase: :one_more_full_or_set,
          stock_market: :current_or,
        }.freeze

        SELL_AFTER = :operate
        SELL_MOVEMENT = :none
        SOLD_OUT_INCREASE = true
        MUST_EMERGENCY_ISSUE_BEFORE_EBUY = true
        CLOSED_CORP_TRAINS_REMOVED = false
        CLOSED_CORP_TOKENS_REMOVED = false
        CLOSED_CORP_RESERVATIONS_REMOVED = false
        OBSOLETE_TRAINS_COUNT_FOR_LIMIT = false

        PORT_HEXES = %w[H1].freeze
        PORT_MARKER_HEX = 'I4'
        TOWN_HEXES = %w[C2 D9 D13 D17 E6 E14 E16 F5 F13 F21 G22 H11].freeze
        CITY_HEXES = %w[B11 C6 C18 D5 D15 E2 E8 E12 E22 F3 F9 F11 F17 G4 G6 G10 G16 H3 H7 H21 I6].freeze
        STL_HEXES = %w[B15 B17 C16 C18].freeze
        STL_TOKEN_HEX = ['C18'].freeze
        CHICAGO_HEX = ['H3'].freeze
        SPRINGFIELD_HEX = ['E12'].freeze
        CORPORATION_SIZES = { 2 => :small, 5 => :medium, 10 => :large }.freeze
        IC_STARTING_PRICE = 80.freeze
        IC_LINE_CITY_HEXES = %w[H7 G10 F17 E22].freeze
        BOOM_HEXES = %w[E8 E12].freeze
        BOOM_TILES = %w[P4 S4].freeze
        GALENA_HEX = %w[C2].freeze
        JACKSONVILLE_HEX = %w[D13].freeze
        CVCC_TOWN_HEXES = (TOWN_HEXES - GALENA_HEX - JACKSONVILLE_HEX).freeze
        USY_CITY_HEXES = (CITY_HEXES - CHICAGO_HEX - STL_TOKEN_HEX - IC_LINE_CITY_HEXES).freeze
        PORT_ICON = 'port'.freeze
        PORT_MARKER_COST = 40
        ROGERS_NAME = 'Rogers (1+1)'
        FRINK_SUBSIDY = 10
        USML_SUBSIDY = 10
        IC_LINE_SUBSIDY = 20
        ICC_REVENUE_BONUS = 100
        EW_BONUS = 80
        NS_BONUS = 100
        BOOM_HEX_TILE = { 'E8' => 'P4', 'E12' => 'S4' }.freeze

        ASSIGNMENT_TOKENS = {
          'port' => '/icons/18_il/port.svg',
        }.freeze

        IC_LINE_COUNT = 10
        IC_LINE_ORIENTATION = {
          'H7' => [1, 3],
          'G8' => [4, 0],
          'G10' => [3, 0],
          'G12' => [3, 0],
          'G14' => [1, 3],
          'F15' => [4, 0],
          'F17' => [3, 0],
          'F19' => [1, 3],
          'E20' => [4, 0],
          'E22' => [3, 0],
        }.freeze

        BLOCKING_LOGOS = [
          '/logos/18_il/yellow_blocking.svg', '/logos/18_il/green_blocking.svg',
          '/logos/18_il/brown_blocking.svg', '/logos/18_il/gray_blocking.svg'
        ].freeze

        IMMOBILE_SHARE_PRICE_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Share price may not change',
          desc_detail: 'Share price may not change while IC is trainless.'
        )
        FORCED_WITHHOLD_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'May not pay dividends',
          desc_detail: 'Must withhold earnings while IC is trainless.'
        )
        BORROW_TRAIN_ABILITY = Ability::BorrowTrain.new(
          type: 'borrow_train',
          train_types: %w[2 3 4 5 4+2C 5+1C 8 D],
          description: 'Must borrow train',
          desc_detail: 'While trainless, IC must borrow the cheapest-available train from the Depot when running trains.'
        )
        RECEIVERSHIP_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Modified oper. turn (receivership)',
          desc_detail: 'IC only performs the "run trains" and "buy trains" steps during ' \
                       'its operating turns while in receivership.'
        )
        OPERATING_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Modified operating turn',
          desc_detail: 'IC only performs the "lay track", "place token", "scrap trains", "run trains",  ' \
                       'and "buy trains" steps during its operating turns.'
        )
        TRAIN_BUY_ABILITY = Ability::TrainBuy.new(
          type: 'train_buy',
          description: 'Modified train buy',
          desc_detail: 'IC can only buy and sell trains at face value. ' \
                       'IC is not required to own a train, but must buy one train if possible.',
          face_value: true
        )
        TRAIN_LIMIT_ABILITY = Ability::TrainLimit.new(
          type: 'train_limit',
          increase: 1,
          description: 'Train limit + 1',
          desc_detail: "IC's train limit is one higher than the current limit"
        )
        STOCK_PURCHASE_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Treasury shares available in ARs',
          desc_detail: 'IC treasury shares are only available during auction rounds.'
        )
        FORMATION_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Unavailable until IC Formation',
          desc_detail: 'IC is unavailable until the IC Formation, which occurs immediately after the operating turn  ' \
                       'of the corporation that completes the IC Line.'
        )

        IC_TRAINLESS_ABILITIES = [
          self::FORCED_WITHHOLD_ABILITY,
          self::IMMOBILE_SHARE_PRICE_ABILITY,
          self::BORROW_TRAIN_ABILITY,
        ].freeze

        def next_round!
          @round =
            case @round
            when G18IL::Round::Draft
              if full_draft_variant?
                init_round_finished
                new_stock_round
              else
                log_development_pool_privates!
                new_auction_round
              end
            when Engine::Round::Auction
              clear_programmed_actions
              new_stock_round
            when Engine::Round::Stock
              @operating_rounds = @final_operating_rounds || @phase.operating_rounds
              reorder_players
              new_operating_round
            when Engine::Round::Operating
              or_round_finished
              if @round.round_num < @operating_rounds
                new_operating_round(@round.round_num + 1)
              else
                @turn += 1
                or_set_finished
                new_auction_round
              end
            end
        end

        def auction_round
          G18IL::Round::Auction.new(self, [
             G18IL::Step::SelectionAuction,
          ])
        end

        def stock_round
          G18IL::Round::Stock.new(self, [
            G18IL::Step::HomeToken,
            G18IL::Step::BuyNewTokens,
            G18IL::Step::BaseBuySellParShares,
          ])
        end

        def par_prices
          types = %i[par]
          types << :par_1 unless %w[2 3].include?(phase.name)
          stock_market.share_prices_with_types(types)
        end

        def operating_round(round_num)
          G18IL::Round::Operating.new(self, [
            Engine::Step::Exchange,
            G18IL::Step::SpecialTrack,
            G18IL::Step::SpecialToken,
            Engine::Step::HomeToken,
            G18IL::Step::ObsoleteTrain,
            G18IL::Step::ExchangeChoiceCorp,
            G18IL::Step::ExchangeChoicePlayer,
            G18IL::Step::Merge,
            Engine::Step::DiscardTrain,
            G18IL::Step::Conversion,
            G18IL::Step::PostConversionShares,
            G18IL::Step::BuyNewTokens,
            G18IL::Step::ConversionPrivateChoice,
            G18IL::Step::IssueShares,
            G18IL::Step::SpecialBuy,
            G18IL::Step::Track,
            G18IL::Step::Token,
            G18IL::Step::BorrowTrain,
            G18IL::Step::CorporateSellShares,
            G18IL::Step::BuyTrainBeforeRunRoute,
            G18IL::Step::RouteExtension,
            G18IL::Step::Route,
            G18IL::Step::Dividend,
            G18IL::Step::SpecialBuyTrain,
            G18IL::Step::BuyTrain,
            G18IL::Step::IcFormationCheck,
          ], round_num: round_num)
        end

        def init_round
          if full_draft_variant?
            new_full_draft_round
          elsif draft_variant?
            new_private_draft_round
          else
            new_auction_round
          end
        end

        def new_private_draft_round
          @log << '-- Private Draft --'
          G18IL::Round::Draft.new(self, [G18IL::Step::PrivateDraft])
        end

        def new_full_draft_round
          @log << '-- Full Draft --'
          G18IL::Round::Draft.new(self, [G18IL::Step::FullDraft])
        end

        def log_development_pool_privates!
          privates = development_pool_privates
          return if privates.empty?

          @log << "Privates placed in the Development Pool: #{list_with_and(privates.map(&:name))}"
        end

        def new_auction_round
          @log << "-- Auction Round #{@turn} --"
          auction_round
        end

        def entity_can_use_company?(_entity, company)
          step = @round&.active_step
          return false unless step
          return false if private_used?(company)

          # No abilities are usable during IC formation.
          return false if ic_formation_pending?

          # No abilities are usable during the post-conversion share transaction.
          return false if step.is_a?(G18IL::Step::PostConversionShares)

          # Central IL Boom is only available in the gray phase.
          return false if company.sym == 'CIB' && !phase.tiles.include?(:gray)

          # Frink, Walker & Co. cannot place the Galena tile if it is already there.
          return false if company.sym == 'FWC' && hex_by_id(GALENA_HEX.first).tile.name == 'G1'

          # Goodrich Transit Line is usable throughout the owning corporation's operating turn.
          if company.sym == 'GTL' &&
            @round.is_a?(Engine::Round::Operating) &&
            @round.current_operator == company.owner
            return true
          end

          # Apply timing-aware filters that the engine does not provide by default.
          return step.is_a?(G18IL::Step::IssueShares) if company.sym == 'SP'

          return step.class.name.include?('Track') if abilities(company, :tile_lay)

          return step.class.name.include?('Token') if abilities(company, :token)

          return step.class.name.include?('BuyTrain') if abilities(company, :train_buy) || abilities(company, :train_discount)

          true
        end

        def tile_lays(entity)
          return super if intro_game?

          # Engineering Mastery permits two upgrades for $20, while Efficient Construction makes the
          # normal second lay free.
          if company_by_id('EM')&.owner == entity
            lays = [{ lay: true, upgrade: true, cost: 0, cannot_reuse_same_hex: true }]

            lays << if @round.upgraded_track
                      { lay: true, upgrade: true, cost: 20, upgrade_cost: 20, cannot_reuse_same_hex: true }
                    else
                      { lay: true, upgrade: true, cost: 20, cannot_reuse_same_hex: true }
                    end
            lays
          elsif company_by_id('EC')&.owner == entity
            [
              { lay: true, upgrade: true, cost: 0 },
              { lay: true, upgrade: :not_if_upgraded, cost: 0, cannot_reuse_same_hex: true },
            ]
          else
            super
          end
        end

        def private_used?(company)
          company&.meta&.dig(:type) == :private &&
            company.instance_variable_get(:@g18_il_used)
        end

        def flip_private!(company, silent: false)
          # Flipped privates remain in their class slot but no longer provide any abilities.
          return unless company&.meta&.dig(:type) == :private
          return if private_used?(company)

          company.all_abilities.dup.each { |ability| company.remove_ability(ability) }
          company.instance_variable_set(:@start_count, nil)
          company.instance_variable_set(:@g18_il_used, true)
          return if silent

          owner = company.owner ? " (#{company.owner.name})" : ''
          @log << "#{company.name}#{owner} is flipped"
        end

        def status_array(corp)
          status = []
          company = @companies.find { |c| c.sym == corp.name }
          status << "Concession: #{company.owner.name}" if company&.owner&.player?
          status << "Option cubes: #{@option_cubes[corp]}" if @option_cubes[corp].positive?
          status << "Loan amount: #{format_currency(corp.loans.first.amount)}" unless corp.loans.empty?
          status << 'Has not operated' if !corp.operated? && corp.floated?
          status.empty? ? nil : status
        end

        def can_par?(corporation, entity)
          # A player may only start a corporation whose concession they own.
          return false unless concession_ok?(entity, corporation)

          super
        end

        def ic
          @ic ||= corporation_by_id('IC')
        end

        def ic_formation_triggered?
          @ic_formation_triggered
        end

        def concession_ok?(player, corp)
          return false unless player.player?

          player.companies.any? { |c| c.sym == corp.name }
        end

        def return_concessions!
          # Unused concessions and their associated privates return to the Auction Pool after each stock round.
          companies.select { |company| company.meta[:type] == :concession }.each do |c|
            next unless c&.owner&.player?

            player = c.owner
            player.companies.delete(c)
            c.owner = nil
            @log << "The #{c.sym} concession has not been used by #{player.name} and has been returned"
          end
        end

        def finish_stock_round
          assign_ic_operator! if ic_in_receivership? && ic_formation_triggered?
        end

        def company_status_str(company)
          statuses = []
          statuses << 'Used' if private_used?(company)
          if !company.owner && !@round.is_a?(G18IL::Round::Draft) && development_pool_privates.include?(company)
            statuses << 'Development Pool'
          end

          statuses.empty? ? nil : statuses.join(' | ')
        end

        def purchasable_companies(entity = nil)
          step = @round&.active_step
          return step.eligible_private_companies if step.is_a?(G18IL::Step::ConversionPrivateChoice)

          super
        end

        def company_header(company)
          case company.meta[:type]
          when :share then 'ORDINARY SHARE'
          when :presidents_share then "PRESIDENT'S SHARE"
          when :concession then 'CONCESSION'
          when :private then "CLASS #{company.meta[:class]} PRIVATE"
          when :lot then 'BIG LOT'
          end
        end

        def corporation_size(entity)
          # Change the stock market token size based on the corporation's share count.
          CORPORATION_SIZES[entity.total_shares]
        end

        def corporation_size_name(entity)
          entity.total_shares.to_s
        end

        def float_str(_entity)
          '2 shares to start'
        end

        def bank_sort(corporations)
          corporations.sort_by { |corporation| @corporations.index(corporation) }
        end

        # Keep references to tiles that are only placeable via private company abilities.
        PRIVATE_ABILITY_TILES = %w[838 P4 S4].freeze

        def find_private_ability_tile(name)
          @private_ability_tile_pool&.find { |t| t.name == name && !t.hex }
        end

        def unowned_purchasable_companies(_entity)
          return [] if big_lots_first_turn?

          @companies
            .select { |c| !c.owner && !c.closed? && %i[A B].include?(c.meta[:class]) }
            .sort_by { |c| [c.meta[:class].to_s, c.name] }
        end

        def setup_preround
          super
          # Northern Cross starts with the 'Rogers' train.
          nc_corp = @corporations.find { |c| c.id == 'NC' }
          train = @depot.trains.find { |t| t.name == ROGERS_NAME }
          @depot.remove_train(train)
          train.buyable = false
          train.owner = nc_corp
          train.obsolete = true
          nc_corp.trains << train

          @log << "Northern Cross Railroad starts with the #{ROGERS_NAME} train"

          # In the intro game, P4/S4 are normal gray tiles without the CIB restriction.
          @private_ability_tile_pool = @tiles.select { |t| PRIVATE_ABILITY_TILES.include?(t.name) } unless intro_game?

          # Create and initialize the blocking corporation for placing blocking tokens in STL.
          create_blocking_corp

          # Set up corporations for the intro game or regular game.
          if big_lots_variant?
            setup_big_lots
          elsif !intro_game? && !draft_variant? && !full_draft_variant?
            initial_auction_pool_setup
          end
        end

        # Create the corporation that places blocking tokens in St. Louis.
        def create_blocking_corp
          @stl_blocking_corp = Corporation.new(
            sym: 'STLBC', name: 'stl_blocking_corp', logo: BLOCKING_LOGOS[0],
            simple_logo: BLOCKING_LOGOS[0], tokens: [0]
          )
          @stl_blocking_corp.owner = @bank

          # Find the city where the blocking tokens will be placed.
          city = @hexes.find { |hex| hex.id == STL_TOKEN_HEX.first }.tile.cities.first

          # Place blocking tokens in the city for each color.
          BLOCKING_LOGOS.each do |logo|
            token = Token.new(@stl_blocking_corp, price: 0, logo: logo, simple_logo: logo, type: :blocking)
            city.place_token(@stl_blocking_corp, token, check_tokenable: false)
          end
        end

        def intro_game?
          optional_rules&.include?(:intro_game)
        end

        def full_draft_variant?
          optional_rules&.include?(:full_draft_variant)
        end

        def big_lots_variant?
          optional_rules&.include?(:big_lots_variant) && [2, 4].include?(@players.size)
        end

        def privates_in_auction_pool?
          !intro_game? && ic_formation_triggered?
        end

        def development_pool_privates
          # The Development Pool is derived from open, unowned privates rather than stored as a separate collection.
          return [] if intro_game? || ic_formation_triggered? || big_lots_first_turn?

          @companies.select do |company|
            company.meta[:type] == :private && company.owner.nil? && !company.closed?
          end
        end

        def eligible_private_acquisitions(corp, player)
          # Five-share corporations may fill a B slot; ten-share corporations may fill A and B slots from the president.
          # Before IC forms, ten-share corporations may take only an A and five-share corporations only
          # a B from the pool.
          return [] if !corp || corp.total_shares <= 2
          return [] if corp == ic

          assigned_classes = used_private_classes(corp)

          player_classes = (corp.total_shares == 5 ? %i[B] : %i[A B]) - assigned_classes
          player_privates =
            if player.is_a?(Engine::Player)
              player.companies.select do |company|
                company.meta[:type] == :private && player_classes.include?(company.meta[:class])
              end
            else
              []
            end

          development_class = corp.total_shares == 5 ? :B : :A
          development_privates =
            if assigned_classes.include?(development_class)
              []
            else
              development_pool_privates.select { |company| company.meta[:class] == development_class }
            end

          player_privates + development_privates
        end

        def player_private_acquisitions(corp, player)
          return [] unless player.is_a?(Engine::Player)

          eligible_private_acquisitions(corp, player).select { |company| company.owner == player }
        end

        def used_private_classes(corp)
          @companies
            .select { |company| company.meta[:type] == :private && company.owner == corp }
            .map { |company| company.meta[:class] }
            .uniq
        end

        def draft_variant?
          optional_rules&.include?(:draft_variant)
        end

        def big_lots_first_turn?
          big_lots_variant? && @turn == 1 && @lot_choice_proxy && !@lot_choice_proxy.closed?
        end

        def setup_big_lots
          # Proxy companies represent each lot during the auction without transferring the underlying items prematurely.
          @log << '-- Big Lots Formation --'

          class_a = @companies.select { |company| company.meta[:class] == :A }.sort_by { rand }
          class_b = @companies.select { |company| company.meta[:class] == :B }.sort_by { rand }
          @big_lot_assigned_players = []

          @lots = if two_player?
                    bucket = @corporations.select(&:floatable).group_by(&:total_shares)
                    ten_shares = bucket[10].sort_by { rand }
                    five_shares = bucket[5].sort_by { rand }
                    two_shares = bucket[2].sort_by { rand }

                    Array.new(2) do
                      corporations = [ten_shares.shift, five_shares.shift, five_shares.shift, two_shares.shift].compact
                      concessions = corporations.map { |corp| @companies.find { |company| company.sym == corp.name } }
                      concessions + class_a.shift(4) + class_b.shift(4)
                    end
                  else
                    concessions = @companies.select { |company| company.meta[:type] == :concession }.sort_by { rand }
                    Array.new(4) { concessions.shift(2) + class_a.shift(2) + class_b.shift(2) }
                  end

          @lot_proxies = @lots.map.with_index { |_lot, index| make_lot_company(index) }
          @lot_choice_proxy = make_lot_choice_company
          @companies |= @lot_proxies
          update_cache(:companies)

          @lots.each_with_index do |lot, index|
            @log << "Lot #{index + 1}: #{list_with_and(lot.map(&:name))}"
          end
        end

        def make_lot_company(index)
          Engine::Company.new(
            sym: "LOT#{index + 1}",
            name: "LOT #{index + 1}",
            value: 10,
            revenue: 0,
            desc: lot_description(index),
            color: '#333333',
            text_color: 'white',
            abilities: [],
            meta: { type: :lot, lot_index: index },
          )
        end

        def make_lot_choice_company
          Engine::Company.new(
            sym: 'LOTCHOICE',
            name: 'RIGHT TO CHOOSE A LOT',
            value: 10,
            revenue: 0,
            desc: 'The auction winner pays the bank, then chooses one of the available lots.',
            color: '#333333',
            text_color: 'white',
            abilities: [],
            meta: { type: :lot_choice },
          )
        end

        def lot_description(index)
          lot = @lots[index]
          concessions = lot.select { |company| company.meta[:type] == :concession }
                           .sort_by { |company| [company.meta[:share_count], company.sym] }
          class_a = lot.select { |company| company.meta[:class] == :A }.sort_by(&:name)
          class_b = lot.select { |company| company.meta[:class] == :B }.sort_by(&:name)

          [
            "#{bold('CONCESSIONS')}\n#{concessions.map { |company| lot_concession_name(company) }.join("\n")}",
            "#{bold('CLASS A PRIVATES')}\n#{class_a.map(&:name).join("\n")}",
            "#{bold('CLASS B PRIVATES')}\n#{class_b.map(&:name).join("\n")}",
          ].join("\n\n")
        end

        def lot_concession_name(company)
          "#{company.name} (#{company.sym})"
        end

        BOLD_MAP = {
          'A' => '𝐀',
          'B' => '𝐁',
          'C' => '𝐂',
          'D' => '𝐃',
          'E' => '𝐄',
          'F' => '𝐅',
          'G' => '𝐆',
          'H' => '𝐇',
          'I' => '𝐈',
          'J' => '𝐉',
          'K' => '𝐊',
          'L' => '𝐋',
          'M' => '𝐌',
          'N' => '𝐍',
          'O' => '𝐎',
          'P' => '𝐏',
          'Q' => '𝐐',
          'R' => '𝐑',
          'S' => '𝐒',
          'T' => '𝐓',
          'U' => '𝐔',
          'V' => '𝐕',
          'W' => '𝐖',
          'X' => '𝐗',
          'Y' => '𝐘',
          'Z' => '𝐙',
          'a' => '𝐚',
          'b' => '𝐛',
          'c' => '𝐜',
          'd' => '𝐝',
          'e' => '𝐞',
          'f' => '𝐟',
          'g' => '𝐠',
          'h' => '𝐡',
          'i' => '𝐢',
          'j' => '𝐣',
          'k' => '𝐤',
          'l' => '𝐥',
          'm' => '𝐦',
          'n' => '𝐧',
          'o' => '𝐨',
          'p' => '𝐩',
          'q' => '𝐪',
          'r' => '𝐫',
          's' => '𝐬',
          't' => '𝐭',
          'u' => '𝐮',
          'v' => '𝐯',
          'w' => '𝐰',
          'x' => '𝐱',
          'y' => '𝐲',
          'z' => '𝐳',
        }.freeze

        def bold(str)
          str.gsub(/./) { |c| BOLD_MAP[c] || c }
        end

        def assign_big_lot!(lot_index, player)
          @lots[lot_index].each do |company|
            company.owner = player
            player.companies << company unless player.companies.include?(company)
          end
          @big_lot_assigned_players << player unless @big_lot_assigned_players.include?(player)
          @lot_proxies[lot_index].close!
        end

        def resolve_big_lots!(winner, lot_index)
          assign_big_lot!(lot_index, winner)
          @log << "#{winner.name} receives #{lot_proxies[lot_index].name}: #{list_with_and(@lots[lot_index].map(&:name))}"

          remaining_players = big_lot_unassigned_players
          remaining_indices = available_big_lot_indices
          return false unless remaining_players.one? && remaining_indices.one?

          player = remaining_players.first
          remaining_index = remaining_indices.first
          assign_big_lot!(remaining_index, player)
          @log << "#{player.name} receives the remaining #{lot_proxies[remaining_index].name} for free: " \
                  "#{list_with_and(@lots[remaining_index].map(&:name))}"

          close_big_lot_proxies!
          true
        end

        def resolve_big_lots_randomly!
          lot_indices = available_big_lot_indices.sort_by { rand }

          big_lot_unassigned_players.each_with_index do |player, index|
            lot_index = lot_indices[index]
            assign_big_lot!(lot_index, player)
            @log << "#{player.name} randomly receives #{lot_proxies[lot_index].name}: " \
                    "#{list_with_and(@lots[lot_index].map(&:name))}"
          end

          close_big_lot_proxies!
        end

        def big_lot_unassigned_players
          @players - @big_lot_assigned_players
        end

        def available_big_lot_indices
          @lot_proxies.each_index.reject { |index| @lot_proxies[index].closed? }
        end

        def close_big_lot_proxies!
          # Once lots are assigned, remove their temporary cards and expose the underlying companies normally.
          proxies = @lot_proxies + [@lot_choice_proxy]

          proxies.each(&:close!)
          @companies.delete_if { |company| proxies.include?(company) }
          update_cache(:companies)
        end

        def draft_style_private_reset?
          draft_variant? || full_draft_variant? || big_lots_variant?
        end

        # Attach the regular-game privates before the first auction round.
        def initial_auction_pool_setup
          class_a = @companies.select { |c| c.meta[:class] == :A }
          class_b = @companies.select { |c| c.meta[:class] == :B }
          class_a = class_a.sort_by { rand }
          class_b = class_b.sort_by { rand }

          @log << '-- Auction Pool Formation --'

          floatable = @corporations.select(&:floatable)
          ten_share_corps = floatable.select { |c| c.type == :ten_share }
          five_share_corps = floatable.select { |c| c.type == :five_share }

          ten_share_corps.each_with_index do |corp, index|
            company_a = class_a[index]
            company_b = class_b[index]
            [company_a, company_b].each do |company|
              company.owner = corp
              company.instance_variable_set(:@color, corp.color)
              company.instance_variable_set(:@text_color, corp.text_color)
              corp.companies << company
            end
            @log << "#{company_a.name} and #{company_b.name} assigned to #{corp.name} concession"
          end

          five_share_corps.each_with_index do |corp, index|
            company_b = class_b[ten_share_corps.size + index]
            company_b.owner = corp
            company_b.instance_variable_set(:@color, corp.color)
            company_b.instance_variable_set(:@text_color, corp.text_color)
            corp.companies << company_b
            @log << "#{company_b.name} assigned to #{corp.name} concession"
          end

          log_development_pool_privates!
        end

        def list_with_and(array)
          return '' if array.empty?
          return array.first.to_s if array.size == 1
          return array.join(' and ') if array.size == 2

          "#{array[0..-2].join(', ')}, and #{array[-1]}"
        end

        def train_help(_entity, runnable_trains, _routes)
          help = []

          runnable_trains.each do |t|
            case t&.name
            when ROGERS_NAME
              help << "The 'Rogers' train may only run a route from Springfield to Jacksonville."
            when '0+3C'
              help << 'A 0+3C train can visit three cities, doubling their value. It may not visit red areas.'
            when '4+2C'
              help << 'A 4+2C train can visit six cities or red areas, doubling the value of two cities.'
            when '5+1C'
              help << 'A 5+1C train can visit six cities or red areas, doubling the value of one city.'
            when 'D'
              help << 'A D train can visit an unlimited number of stops along a single route.'
            end
          end

          help.uniq
        end

        def setup
          ic.add_ability(self.class::FORMATION_ABILITY)
          ic.owner = nil
          @insolvent_corporations = []
          @last_set_pending = nil
          @last_set = nil
          @ic_needs_train = false
          @ic_owns_train = false
          @ic_formation_triggered = nil
          @ic_formation_pending = nil
          @merge_share_prices = []
          @merged_min_entity_index = nil
          @closed_corporations = []
          @train_borrowed = nil
          @borrowed_trains = {}
          @merged_corps = []
          @ic_trigger_entity = nil
          @emr_active = nil
          @option_cubes ||= Hash.new(0)
          @ic_line_completed_hexes = []
          @operated_mergees = []

          port_marker_city.add_reservation!(company_by_id('GTL'), 0) unless intro_game?
          port_marker_city.add_reservation!(ic, 1)

          @corporations.select { |corp| corp.type == :two_share }.each { |c| c.max_ownership_percent = 100 }

          @reserved_shares = {}
          unless intro_game?
            @corporations.each do |corp|
              next if corp == ic
              next unless corp.total_shares == 10

              reserve_last_share(corp)
            end
          end

          @stl_nodes = STL_HEXES.map do |h|
            hex_by_id(h).tile.nodes.find { |n| n.offboard? && n.groups.include?('STL') }
          end

          # Remove the 838 and G1 tiles in the intro game.
          @all_tiles.each { |tile| tile.hide if %w[G1 838].include?(tile.name) } if intro_game?

          # Color private companies by class so they are visually distinct on the Entities page.
          @companies.each do |company|
            next unless company.meta[:type] == :private
            next if company.color != :yellow

            if company.meta[:class] == :A
              company.instance_variable_set(:@color, '#006d6d')
              company.instance_variable_set(:@text_color, 'white')
            else
              company.instance_variable_set(:@color, '#a3c9c9')
              company.instance_variable_set(:@text_color, 'black')
            end
          end
        end

        def ipo_name(_entity = nil) = 'Treasury'
        def ipo_verb(_entity = nil) = 'starts'
        def ipo_reserved_name(_entity = nil) = 'Reserve'

        def setup_optional_rules
          return unless @optional_rules

          add_optional_train('3',  (@optional_rules.include?(:one_extra_three_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_three_trains) ? 2 : 0))
          add_optional_train('4',  (@optional_rules.include?(:one_extra_four_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_four_trains) ? 2 : 0))
          add_optional_train('5', (@optional_rules.include?(:one_five_train) ? 1 : 0) +
                                (@optional_rules.include?(:two_five_trains) ? 2 : 0))
          add_optional_train('4+2C', (@optional_rules.include?(:one_extra_four_plus_two_p_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_four_plus_two_p_trains) ? 2 : 0))
          add_optional_train('5+1C', (@optional_rules.include?(:one_extra_five_plus_one_p_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_five_plus_one_p_trains) ? 2 : 0))
          add_optional_train('8', (@optional_rules.include?(:one_extra_eight_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_eight_trains) ? 2 : 0))
        end

        def add_optional_train(type, count)
          return if count <= 0

          proto = self.class::TRAINS.find { |e| e[:name] == type }
          raise GameError, "Unknown train type: #{type}" unless proto

          base_stack_index = @depot.trains.count { |t| t.name == type }

          last_same_idx = @depot.upcoming.rindex { |t| t.name == type }
          if last_same_idx
            insert_base = last_same_idx + 1
          else
            roster_order = self.class::TRAINS.map { |t| t[:name] }
            target_pos   = roster_order.index(type) || roster_order.length
            insert_base = @depot.upcoming.index do |t|
              (roster_order.index(t.name) || roster_order.length) > target_pos
            end || @depot.upcoming.length
          end

          count.times do |i|
            new_train = Train.new(**proto, index: base_stack_index + i)
            @depot.insert_train(new_train, insert_base + i)
          end

          update_cache(:trains)
        end

        def emr_active?
          @emr_active
        end

        def owns_port_marker?(corporation)
          port_marker_city.tokened_by?(corporation)
        end

        def assign_port_icon(corp)
          return if owns_port_marker?(corp)

          city = port_marker_city
          token = Token.new(corp, price: 0)
          reserved_slot = city.find_reservation(corp)
          city.place_token(corp, token, free: true, check_tokenable: false)
          city.reservations[reserved_slot] = nil if reserved_slot
        end

        def port_marker_city
          hex_by_id(PORT_MARKER_HEX).tile.cities.first
        end

        def rust_trains!(train, entity)
          # Delay the rust event only when Planned Obsolescence has an eligible train to save.
          ic_needs_train! if entity == ic && ic.trains.empty?
          return super if intro_game? || !po_can_save_rusting_train?(train)

          @pending_rusting_event = { train: train, entity: entity }
        end

        def po_can_save_rusting_train?(purchased_train)
          !@pending_rusting_event &&
            !private_used?(company_by_id('PO')) &&
            (owner = company_by_id('PO').owner) &&
            owner.corporation? &&
            owner.trains.any? { |t| rust?(t, purchased_train) }
        end

        def company_sellable(company); end

        def upgrades_to?(from, to, special = false, selected_company: nil)
          # P4 and S4 are available in the intro game, but only to Central IL Boom in the normal game.
          if !intro_game? && BOOM_HEXES.include?(from.hex.id)
            if selected_company == company_by_id('CIB') && phase.tiles.include?(:gray)
              return to.name == BOOM_HEX_TILE[from.hex.id]
            end

            return false if self.class::BOOM_TILES.include?(to.name)
          end

          # CVCC may place the private-only 838 tile on otherwise compatible town hexes.
          return true if !intro_game? && TOWN_HEXES.include?(from.hex.id) &&
          to.name == '838' && selected_company == company_by_id('CVCC')

          super
        end

        def tile_valid_for_phase?(tile, hex: nil, phase_color_cache: nil)
          # Tile 838 remains available regardless of phase because only CVCC may place it.
          return true if tile.name == '838'

          super
        end

        def eligible_tokens?(corporation)
          corporation.tokens.find do |token|
            token.used && token.status == :flipped && !STL_TOKEN_HEX.include?(token.hex.id)
          end
        end

        def place_home_token(corporation)
          # Reopened corporations reuse a flipped token when possible; otherwise they choose a new home.
          return super unless @closed_corporations.include?(corporation)

          @log << if eligible_tokens?(corporation)
                    "#{corporation.name} must choose token to flip"
                  else
                    "#{corporation.name} must choose city for home token"
                  end
          @round.pending_tokens << {
            entity: corporation,
            hexes: home_token_locations(corporation),
            token: corporation.tokens.first,
          }
          @round.clear_cache!
        end

        def home_token_locations(corporation)
          # A reopened corporation may flip one of its map tokens, except in STL.
          if eligible_tokens?(corporation)
            corporation.tokens
              .select { |token| token.used && token.status == :flipped && !STL_TOKEN_HEX.include?(token.hex.id) }
              .map(&:hex)
              .uniq
          else
            # Otherwise, it may place a token in any available city slot except in Chicago or STL.
            hexes.select do |hex|
              hex.tile.cities.any? { |c| c.tokenable?(corporation) } &&
              !STL_TOKEN_HEX.include?(hex.id) && !CHICAGO_HEX.include?(hex.id)
            end
          end
        end

        def update_ic_abilities!(add:)
          # IC gains borrowing, forced-withhold, and immobile-price abilities only while trainless.
          IC_TRAINLESS_ABILITIES.each do |ability|
            if add
              ic.add_ability(ability)
            else
              ic.remove_ability(ability)
            end
          end
        end

        def ic_needs_train!
          @ic_owns_train = false
          return if @ic_needs_train

          @ic_needs_train = true
          update_ic_abilities!(add: true)
        end

        def ic_owns_train!
          @ic_needs_train = false
          return if @ic_owns_train

          @ic_owns_train = true
          update_ic_abilities!(add: false)
        end

        def close_corporation(corporation)
          # Closing preserves the concession, open privates, trains, and flipped map tokens so the corporation can
          # reopen. Solvent corporations also preserve their cash.
          president = corporation.owner
          @mergeable_candidates&.delete(corporation)

          @closed_corporations << corporation
          @log << "#{corporation.name} closes"

          if @round&.operating? && @round.entities&.include?(corporation)
            idx = @round.entities.index(corporation)
            was_current = (@round.current_entity == corporation)

            if was_current
              @round.force_next_entity!
              @round.entities.delete_at(idx)
            else
              @round.entities.delete_at(idx)
              @round.entity_index -= 1 if idx < @round.entity_index
            end

            @round.entity_index = @round.entity_index.clamp(0, @round.entities.size - 1) if @round.entities.any?
          end

          # Remove the corporation from the IPO.
          corporation.share_price&.corporations&.delete(corporation)
          corporation.share_price = nil
          corporation.par_price = nil
          corporation.ipoed = false
          corporation.unfloat!

          # Sell the corporation's IC shares to the Market.
          ic_shares = corporation.shares_of(ic)
          if ic_shares&.any?
            @bank.spend(ic_shares.size * ic.share_price.price, corporation)
            @share_pool.transfer_shares(ShareBundle.new(ic_shares), @share_pool)
          end

          @corporations.each do |c|
            next if c == corporation

            c.share_holders.keys.each do |share_holder|
              next unless share_holder == corporation

              shares = share_holder.shares_by_corporation[c].compact
              c.share_holders.delete(share_holder)
              shares.each do |share|
                share_holder.shares_by_corporation[c].delete(share)
                share.owner = c
                c.shares_by_corporation[c] << share
                @share_pool.transfer_shares(share.to_bundle, @share_pool)
              end
              c.shares_by_corporation[c].sort_by!(&:index)
            end
          end

          forgive_debt_on_close!(corporation)

          # Return shares to the IPO.
          corporation.share_holders.keys.each do |share_holder|
            next if share_holder == corporation

            shares = share_holder.shares_by_corporation[corporation].compact
            corporation.share_holders.delete(share_holder)
            shares.each do |share|
              share_holder.shares_by_corporation[corporation].delete(share)
              share.owner = corporation
              corporation.shares_by_corporation[corporation] << share
            end
          end
          corporation.shares_by_corporation[corporation].sort_by!(&:index)
          corporation.share_holders[corporation] = 100
          corporation.owner = nil

          # Flip all map tokens and return the Union Stock Yards token to the charter.
          corporation.tokens.each do |token|
            next unless token.used

            # Return the USY token to its owner's charter.
            if token.extra
              token.remove!
            else
              token.status = :flipped
            end
          end

          # Remove the home location.
          corporation.coordinates = nil

          # Pass the concession to the president.
          company = company_by_id(corporation.name)
          company.owner = president
          president.companies << company
          @companies << company
          @companies = @companies.sort

          close_corporations_in_close_cell!
        end

        def forgive_debt_on_close!(corporation)
          return unless @insolvent_corporations.include?(corporation)

          debt = corporation.loans.sum(&:amount)
          cash = corporation.cash
          corporation.spend(cash, @bank) if cash.positive?
          corporation.loans.clear
          @insolvent_corporations.delete(corporation)

          @log << "#{corporation.name}'s debt of #{format_currency(debt)} is forgiven"
          @log << "#{format_currency(cash)} is removed from #{corporation.name}'s charter" if cash.positive?
          @log << "-- #{corporation.name} is now solvent --"
        end

        def ic_line_hex?(hex)
          IC_LINE_ORIENTATION[hex.name]
        end

        def ic_line_improvement(action)
          hex = action.hex
          icons = hex.tile.icons
          corp = action.entity.corporation

          return if @ic_line_completed_hexes.include?(hex)

          connection_count = ic_line_connections(hex)
          return unless connection_count == 2

          complete_ic_line_for(hex, icons, corp)
          log_ic_line_progress

          return unless ic_line_completed?

          trigger_ic_formation!(action.entity)
        end

        def complete_ic_line_for(hex, icons, corp)
          @ic_line_completed_hexes << hex

          icons.each do |icon|
            next unless icon.sticky

            icons.delete(icon)
            next if corp == ic

            @option_cubes[corp] += 1
            @log << "#{corp.name} receives an option cube"
          end
        end

        def log_ic_line_progress
          @log << "IC Line hexes completed: #{@ic_line_completed_hexes.size} of 10"
        end

        def trigger_ic_formation!(entity)
          if phase.name == 'D'
            @log << 'IC Line is complete, but does not form in phase D'
          else
            @log << 'IC Line is complete'
            @log << "-- The Illinois Central Railroad will form at the end of #{entity.name}'s turn --"
            @ic_formation_triggered = true
            @ic_formation_pending = true
            @ic_trigger_entity = entity
          end
        end

        def ic_formation_pending?
          @ic_formation_pending
        end

        def ic_line_connections(hex)
          return 0 unless (exits = IC_LINE_ORIENTATION[hex.name])

          paths = hex.tile.paths
          count = 0
          paths.each do |path|
            path.exits.each do |exit|
              (count += 1) if exits.include?(exit)
            end
          end
          count
        end

        def ic_line_completed?
          @ic_line_completed_hexes.size == IC_LINE_COUNT
        end

        # Shared IC Line tile logic called after lay_tile_action.
        # beneficiary: the entity that receives the yellow-phase subsidy (differs between
        # a regular corp tile lay vs. a private company special tile lay).
        def process_ic_line(action, beneficiary:, round:)
          ic_line_improvement(action)

          hex = action.hex
          tile = hex.tile
          city = tile.cities.first

          case tile.color
          when :yellow
            raise GameError, 'Tile must overlay at least one section of the dashed path' if ic_line_connections(hex) < 1

            @log << "#{beneficiary.name} receives a #{format_currency(IC_LINE_SUBSIDY)} subsidy from the bank "\
                    '(IC Line improvement)'
            bank.spend(IC_LINE_SUBSIDY, beneficiary)
          when :green
            raise GameError, 'Tile must complete IC Line' if ic_line_connections(hex) < 2

            if round.num_laid_track > 1 && round.laid_hexes.first.tile.color == :green &&
               self.class::IC_LINE_CITY_HEXES.include?(round.laid_hexes.first)
              raise GameError, 'Cannot upgrade two incomplete IC Line hexes in one turn'
            end

            if self.class::IC_LINE_CITY_HEXES.include?(hex.id) && !ic.tokens.find { |t| t.hex == hex }
              tile.add_reservation!(ic, city)
            end
          when :brown
            tile.remove_reservation!(ic) if self.class::IC_LINE_CITY_HEXES.include?(hex.id)
          end
        end

        def remove_icon(hex, icon_names)
          icon_names.each do |name|
            icons = hex.tile.icons
            icons.reject! { |i| name == i.name }
            hex.tile.icons = icons
          end
        end

        def convert(corporation)
          # Conversion rebuilds the certificate structure while preserving every existing share owner.
          shares = @_shares.values.select { |share| share.corporation == corporation }
          corporation.share_holders.clear
          size = corporation.total_shares
          case size
          when 2
            shares[0].percent = 40
            corporation.float_percent = 40
            new_shares = Array.new(3) { |i| Share.new(corporation, percent: 20, index: i + 1) }
          when 5
            shares.each { |share| share.percent = 10 }
            shares[0].percent = 20
            corporation.float_percent = 20
            new_shares = Array.new(5) { |i| Share.new(corporation, percent: 10, index: i + 4) }
          else
            raise GameError, 'Cannot convert 10-share corporation'
          end
          corporation.max_ownership_percent = 60
          shares.each { |share| corporation.share_holders[share.owner] += share.percent }
          new_shares.each { |share| add_new_share(share) }

          reserve_last_share(corporation) if !intro_game? && corporation != ic && corporation.total_shares == 10
          new_shares
        end

        def add_new_share(share)
          owner = share.owner
          corporation = share.corporation
          corporation.share_holders[owner] += share.percent if owner
          owner.shares_by_corporation[corporation] << share if owner
          @_shares[share.id] = share
        end

        def timeline
          sep = '-' * 260
          @timeline = [
            'End of OR 1.1: All unsold 2-trains are exported*',
            'End of each subsequent OR: The next-available train is exported*',
            sep,
            'IC Formation occurs when IC Line is completed. IC starts at $80 share price with $400 in its treasury',
            'Corporations exchange option cubes for shares of IC. Corps with tokens along IC Line have an ' \
            'opportunity to merge',
            'IC places tokens, adjusts its share price, and buys the first-available train',
            'It operates in the current OR if no mergers occured or no merged corporation had operated',
            'All private companies in the Development Pool move to the Auction Pool',
            sep,
            "The 'Rogers' train runs between Springfield and Jacksonville and rusts immediately after running",
            'An x+yC train may visit x red areas or cities, plus y additional cities that earn double revenue. ' \
            'The doubled cities may be anywhere along the route. The train may also include any number of towns or ports',
          ].freeze
        end

        def purchase_tokens!(corporation, count, total_cost, quiet = false)
          count.times { corporation.tokens << Token.new(corporation, price: 0) }
          auto_emr(corporation, total_cost) if corporation.cash < total_cost
          corporation.spend(total_cost, @bank)
          return if quiet

          @log << "#{corporation.name} buys #{count} #{count == 1 ? 'token' : 'tokens'} for #{format_currency(total_cost)}"
        end

        # Sell IPO shares to make up the shortfall.
        def auto_emr(corp, total_cost)
          diff = total_cost - corp.cash
          return unless diff.positive?

          num_shares = ((2.0 * diff) / corp.share_price.price).ceil
          bundle = ShareBundle.new(corp.shares_of(corp).take(num_shares))
          bundle.share_price = corp.share_price.price / 2.0
          old_price = corp.share_price.price
          sell_shares_and_change_price(bundle, movement: :down_share)
          new_price = corp.share_price.price
          @log << "#{corp.name} raises #{format_currency(bundle.price)} and completes EMR"
          @log << "#{corp.name}'s share price moves down from #{format_currency(old_price)} to #{format_currency(new_price)}"
          @round.recalculate_order if @round.respond_to?(:recalculate_order)
        end

        def all_bundles_for_corporation(share_holder, corporation, shares: nil)
          # Bundle prices vary for Share Premium issues and emergency corporate share sales.
          return [] unless corporation.ipoed

          shares ||= share_holder.shares_of(corporation)
          return [] if shares.empty?

          shares = shares.sort_by { |h| [h.president ? 1 : 0, h.percent] }
          bundle = []
          percent = 0
          all_bundles = shares.each_with_object([]) do |share, bundles|
            bundle << share
            percent += share.percent
            bundles << Engine::ShareBundle.new(bundle, percent)
          end

          if !intro_game? && corporation == company_by_id('SP').owner && sp_toggle_enabled?(corporation)
            all_bundles.each { |b| b.share_price = corporation.share_price.price * 2.0 }

          elsif @round&.steps&.find { |s| s.is_a?(G18IL::Step::CorporateSellShares) }&.active? &&
                !@round&.steps&.find { |s| s.is_a?(Engine::Step::IssueShares) }&.active? &&
                share_holder.is_a?(Corporation)
            all_bundles.each { |b| b.share_price = corporation.share_price.price / 2.0 if corporation != ic }
          end

          all_bundles.concat(partial_bundles_for_presidents_share(corporation, bundle, percent)) if shares.last.president
          all_bundles.sort_by(&:percent)
        end

        def sp_toggle_enabled?(corp)
          sp = company_by_id('SP')
          return false if !sp || sp.owner != corp
          return false unless @round.respond_to?(:steps)

          issue_step = @round.steps.find { |s| s.is_a?(Engine::Step::IssueShares) }
          return false unless issue_step&.active?
          return false unless @round.respond_to?(:sp_issue_toggle)

          !!@round.sp_issue_toggle[corp]
        end

        def sell_shares_and_change_price(bundle, allow_president_change: true, swap: nil, movement: nil)
          # 18IL uses explicit horizontal or diagonal movement instead of the base game's sale movement rules.
          corporation = bundle.corporation
          if (emr_active? && bundle.owner == corporation) || corporation.share_price.price == lowest_stock_price
            movement = :down_share
          end
          # Reserve shares lose their restriction as soon as the corporation issues them to the Market.
          bundle.shares.each { |share| share.buyable = true } if bundle.owner == corporation
          @share_pool.sell_shares(bundle, allow_president_change: allow_president_change, swap: swap)
          case movement || sell_movement(corporation)
          when :down_share
            bundle.num_shares.times { @stock_market.move_down(corporation) }
          when :left_share
            bundle.num_shares.times { @stock_market.move_left(corporation) }
          when :none
            nil
          else
            raise NotImplementedError
          end
        end

        def lowest_stock_price
          @stock_market.market.first[1].price
        end

        def emergency_issuable_cash(corporation)
          return 0 if corporation.trains.any? || @will_buy_other_train

          emergency_issuable_bundles(corporation).max_by(&:num_shares)&.price || 0
        end

        def emergency_issuable_bundles(entity)
          # Emergency issuance sells only the smallest treasury bundle sufficient to reach the next train price.
          return [] if entity == ic
          return [] unless entity.cash < @depot.min_depot_price
          return [] unless entity.corporation?
          return [] if entity.num_ipo_shares.zero?

          bundles = bundles_for_corporation(entity, entity)
          bundles.each { |b| b.share_price = entity.share_price.price / 2.0 }
          eligible, remaining = bundles.partition { |bundle| bundle.price + entity.cash < @depot.min_depot_price }
          remaining.empty? ? [eligible.last].compact : [remaining.first].compact
        end

        def reserve_last_share(corp)
          # A ten-share corporation's final treasury share begins unavailable in its Reserve.
          share = corp.ipo_shares.last
          return unless share

          @reserved_shares[corp.name] = share
          share.buyable = false
        end

        def reserved_share_for(corp)
          @reserved_shares[corp&.name]
        end

        def issuable_shares(entity)
          # A corporation issues one buyable treasury share, falling back to its Reserve when the Treasury is empty.
          return [] unless entity.corporation?

          reserve = reserved_share_for(entity)
          return [] if entity.num_treasury_shares.zero? && reserve&.owner != entity

          bundles = bundles_for_corporation(entity, entity)

          if sp_toggle_enabled?(entity) && reserve&.owner == entity
            reserve_bundle = ShareBundle.new(reserve)
            reserve_bundle.share_price = entity.share_price.price * 2.0
            return [reserve_bundle]
          end

          buyable_bundles = bundles.select(&:buyable).take(1)
          return buyable_bundles unless buyable_bundles.empty?
          return [] unless reserve&.owner == entity

          [ShareBundle.new(reserve)]
        end

        def borrow_train(action)
          # Borrowed trains temporarily belong to IC and are returned after the dividend step.
          entity = action.entity
          train = action.train
          buy_train(entity, train, :free)
          train.operated = false
          @borrowed_trains[entity] = train
          @log << "#{entity.name} borrows a #{train.name} train"
          @train_borrowed = true
        end

        def scrap_train(train)
          owner = train.owner
          @log << "#{owner.name} scraps a #{train.name} train"
          @depot.reclaim_train(train)
        end

        def rust_rogers!(normal_event: false)
          train = corporation_by_id('NC').trains.find { |t| t.name == ROGERS_NAME }
          return unless train

          unless normal_event
            @log << "The #{ROGERS_NAME} train rusts after running"
            rust(train)
            return
          end

          trigger = depot.trains.find { |depot_train| depot_train.sym == '3' }
          rust_trains!(trigger, corporation_by_id('NC'))
        end

        def city_tokened_by?(city, entity)
          return false unless entity&.corporation?
          return false unless city.respond_to?(:tokens)

          # Check normal slots.
          return true if city.tokens.any? { |t| t&.corporation == entity && t.status != :flipped }

          # Check extra slots, if present.
          city.respond_to?(:extra_tokens) &&
            city.extra_tokens.any? { |t| t&.corporation == entity && t.status != :flipped }
        end

        def export_train
          if phase.name == '2'
            depot.export_all!('2')
            phase.next!
            rust_rogers!(normal_event: true)
          elsif phase.name != 'D'
            depot.export!
          elsif phase.name == 'D'
            @last_set_pending = true
          end
        end

        def init_stock_market
          stock_market = G18IL::StockMarket.new(self.class::MARKET, [], zigzag: :flip)
          stock_market.game = self
          stock_market
        end

        def c_bonus(route, stops)
          name = route.train.name
          return 0 unless name.include?('C')

          offboard_groups = %w[West East North South STL]
          cities = stops.select { |s| s.city? && !s.groups.intersect?(offboard_groups) }
          return 0 if cities.empty?

          m = name.match(/(\d+)\s*C/)
          count = m ? m[1].to_i : 0
          return 0 if count.zero?

          n = [count, cities.size].min
          cities.map { |s| s.route_revenue(route.phase, route.train) }
                .max(n)
                .sum
        end

        def ew_ns_bonus(stops)
          bonus = { revenue: 0 }

          east = stops.find { |stop| stop.groups.include?('East') }
          west = stops.find { |stop| stop.groups.include?('West') }
          north = stops.find { |stop| stop.groups.include?('North') }
          south = stops.find { |stop| stop.groups.include?('South') }

          if east && west
            bonus[:revenue] = EW_BONUS
            bonus[:description] = 'E/W'
          end

          if north && south
            bonus[:revenue] = NS_BONUS
            bonus[:description] = 'N/S'
          end

          bonus
        end

        def routes_subsidy(routes)
          return 0 if intro_game?

          subsidy = 0

          company = company_by_id('USML')
          owner = company&.owner
          mail_routes = if !company&.closed? && owner&.corporation?
                          routes.select { |route| operating_corporation_for(route) == owner }
                        else
                          []
                        end
          subsidy += mail_routes.flat_map { |route| city_stops(route) }.uniq.count * USML_SUBSIDY

          subsidy += ICC_REVENUE_BONUS if icc_routes_bonus?(routes)

          subsidy
        end

        def icc_routes_bonus?(routes)
          company = company_by_id('ICC')
          owner = company&.owner

          return false if company&.closed?
          return false unless owner&.corporation?

          routes.any? do |route|
            operating_corporation_for(route) == owner &&
              ew_ns_bonus(route.stops)[:revenue].positive?
          end
        end

        # Pay $10 to the corporation that owns FWC when another corporation visits Galena.
        def pay_fwc_bonus!(routes, entity)
          return if !company_by_id('FWC') || company_by_id('FWC').closed?
          return unless routes.any? { |r| r.hexes.any? { |h| GALENA_HEX.include?(h.id) } }

          owner = company_by_id('FWC').owner
          return unless owner
          return if owner == entity
          return if owner.corporation? && (!owner.ipoed || closed_corporations.include?(owner))

          @bank.spend(FRINK_SUBSIDY, owner)
          @log << "#{owner.name} receives a #{format_currency(FRINK_SUBSIDY)} subsidy " \
                  'from the bank (Frink, Walker, & Co.)'
        end

        def subsidy_for(route, _stops)
          return 0 if intro_game?

          company = company_by_id('USML')
          owner = company&.owner
          return 0 if company&.closed? || !owner&.corporation?
          return 0 if operating_corporation_for(route) != owner

          city_stops(route).count * USML_SUBSIDY
        end

        def operating_corporation_for(route)
          route.corporation || (@round.current_operator if @round.respond_to?(:current_operator))
        end

        def revenue_for(route, stops)
          revenue = super
          revenue += ew_ns_bonus(stops)[:revenue] + c_bonus(route, stops)
          revenue
        end

        def revenue_str(route)
          str = super

          bonus = ew_ns_bonus(route.stops)[:description]
          str += " + #{bonus}" if bonus
          str += ' + ICC' if icc_revenue_str_route?(route)

          str
        end

        def icc_revenue_str_route?(route)
          company = company_by_id('ICC')
          owner = company&.owner

          return false if company&.closed?
          return false unless owner&.corporation?
          return false unless operating_corporation_for(route) == owner
          return false unless ew_ns_bonus(route.stops)[:revenue].positive?

          routes = route.routes
          routes.empty? || routes.find { |r| operating_corporation_for(r) == owner && ew_ns_bonus(r.stops)[:revenue].positive? } == route
        end

        def icc_bonus_route?(route, stops)
          icc_qualifying_route?(route, stops)
        end

        def icc_qualifying_route?(route, stops)
          company = company_by_id('ICC')
          owner = company&.owner

          return false if company&.closed?
          return false unless owner&.corporation?
          return false unless operating_corporation_for(route) == owner

          ew_ns_bonus(stops)[:revenue].positive?
        end

        def city_stops(route)
          route.stops.map do |stop|
            next unless stop.city?

            stop.tile.hex
          end.compact
        end

        def stl_permit?(entity)
          STL_TOKEN_HEX.any? { |h| hex_by_id(h).tile.cities.any? { |c| city_tokened_by?(c, entity) } }
        end

        def stl_hex?(stop)
          @stl_nodes.include?(stop)
        end

        def check_stl(visits)
          return if !stl_hex?(visits.first) && !stl_hex?(visits.last)
          raise GameError, 'Train cannot visit St. Louis without a token' unless stl_permit?(current_entity)
        end

        def check_three_p(route, visits)
          case route.train.name
          when '0+3C'
            raise GameError, 'Cannot visit red areas' if visits.any? { |visit| visit.tile.color == :red }
          when '1+3C'
            raise GameError, 'Cannot visit more than one red area' if visits.count { |visit| visit.tile.color == :red } > 1
          end
        end

        def check_rogers(route, visits)
          return unless route.train.name == ROGERS_NAME
          if (visits.first.hex.name == SPRINGFIELD_HEX.first && visits.last.hex.name == JACKSONVILLE_HEX.first) ||
            (visits.last.hex.name == SPRINGFIELD_HEX.first && visits.first.hex.name == JACKSONVILLE_HEX.first)
            return
          end

          raise GameError, "'Rogers' train can only run between Springfield and Jacksonville"
        end

        def check_port(route, visits)
          return if visits.none? { |v| PORT_HEXES.find { |h| v.hex == hex_by_id(h) } } || owns_port_marker?(route.corporation)

          raise GameError, 'Corporation must own a port permit to visit a port'
        end

        def check_other(route)
          multiple_cities = route.visited_stops
                                 .select(&:city?)
                                 .group_by(&:hex)
                                 .any? { |_hex, cities| cities.size > 1 }
          return unless multiple_cities

          raise GameError, 'Train cannot visit multiple cities in the same hex'
        end

        def check_distance(route, visits)
          # Check STL for a permit token.
          check_stl(visits)

          # Disallow 0+3C trains from running to red areas.
          check_three_p(route, visits)

          # Disallow the Rogers train from running outside Springfield and Jacksonville.
          check_rogers(route, visits)

          # Disallow corporations without a port token from running to a port.
          check_port(route, visits)

          return super if route.train.name == ROGERS_NAME

          first = visits.first
          last  = visits.last

          first_bad = first.town? && !town_endpoint_ok?(first)
          last_bad  = last.town?  && !town_endpoint_ok?(last)

          raise GameError, 'Route cannot begin/end in a town' if first_bad || last_bad

          super
        end

        def town_endpoint_ok?(node)
          node.town? && (node.hex == hex_by_id(PORT_HEXES.first))
        end

        def init_loans
          # Insolvency uses the engine's loan display, but 18IL loans do not charge interest.
          Array.new(8) { |id| Loan.new(id, 0) }
        end

        def maximum_loans(_entity)
          1
        end

        def can_pay_interest?(_entity, _extra_cash = 0)
          false
        end

        def interest_owed(_entity)
          0
        end

        def can_go_bankrupt?(_player, _corp)
          false
        end

        def corporation_show_interest?(_corporation)
          false
        end

        def corporation_show_loans?(corporation)
          insolvent_corporations.include?(corporation)
        end

        def take_loan(corporation, loan)
          # Additional emergency funding increases the corporation's single outstanding debt balance.
          @bank.spend(loan, corporation)

          if insolvent_corporations.include?(corporation)
            @log << "#{corporation.name} adds #{format_currency(loan)} to its existing loan"
            balance = corporation.loans.first.amount + loan
            corporation.loans[0] = Loan.new(corporation, balance)
          else
            @log << "-- #{corporation.name} is now insolvent --"
            @log << "#{corporation.name} takes a loan of #{format_currency(loan)}"
            corporation.loans << Loan.new(corporation, loan)
            @insolvent_corporations << corporation
          end
        end

        def payoff_loan(corporation, payoff_amount: nil)
          loan_balance = corporation.loans.first.amount
          payoff_amount ||= corporation.cash
          payoff_amount = [payoff_amount, loan_balance].min
          return if payoff_amount.zero?

          corporation.loans.shift
          remaining_loan = loan_balance - payoff_amount
          corporation.loans << Loan.new(corporation, remaining_loan)
          corporation.spend(payoff_amount, @bank)

          if remaining_loan.zero?
            @log << "#{corporation.name} pays off its loan of #{format_currency(loan_balance)}"
            @log << "-- #{corporation.name} is now solvent --"
            @insolvent_corporations.delete(corporation)
            corporation.loans.clear
          else
            @log << "#{corporation.name} decreases its loan by #{format_currency(payoff_amount)} " \
                    "(#{format_currency(remaining_loan)} remaining)"
          end
        end

        def round_description(name, round_number = nil)
          return "Auction Round #{@turn}" if name == 'Auction'

          super
        end

        def final_operating_rounds
          @final_operating_rounds || super
        end

        def process_single_action(action)
          corp = action.entity.owner if action.entity.company?
          super

          return if intro_game?

          if action.entity == company_by_id('GTL')
            assign_port_icon(corp)
            log << "#{corp.name} receives a port permit"
          end

          return unless action.entity == company_by_id('CIB')

          tile = action.hex.tile
          tile_to_remove = case tile.name
                           when 'P4' then 'S4'
                           when 'S4' then 'P4'
                           end

          @log << "Tile ##{tile_to_remove} is removed from the game"
          tiles.delete_if { |t| t.name == tile_to_remove }
          @private_ability_tile_pool&.delete_if { |t| t.name == tile_to_remove }
        end

        def or_round_finished
          @last_set_pending = true if phase.name == 'D'
        end

        def or_set_finished
          # No one owns IC while it is in receivership.
          ic.owner = nil if ic_in_receivership?

          return unless phase.name == 'D'

          event_pullman_strike!
          event_remove_non_corporate_companies!
          event_cert_limit_change!
          event_issue_reserve_shares!

          @last_set = true
        end

        # ---------------- EVENTS ----------------------
        def event_signal_end_game!
          # Play one more OR, resolve final events, then play one final set of an AR, SR, and three ORs.
          @final_operating_rounds = 3
          @last_set_triggered = true
          game_end_check
          @operating_rounds = 3 if phase.name == 'D' && round.round_num == 2
          @log << "-- First D train bought/exported, game ends at the conclusion of OR #{@turn + 1}.#{@final_operating_rounds} --"
          @log << "-- At the end of OR #{@turn}.#{@round.round_num + 1}, 4+2C and 5+1C trains will downgrade to " \
                  '4- and 5-trains --'
        end

        # Pullman Strike: C-trains downgrade to their base (non-C) value.
        def event_pullman_strike!
          @log << '-- Event: Pullman Strike --'

          @corporations.each do |corp|
            corp.trains.each do |train|
              name = train.name
              next unless name.include?('C')

              m = name.match(/^(\d+)\s*\+/) || name.match(/(\d+)\s*C\b/) || name.match(/(\d+)/)
              base = m && m[1].to_i

              next unless base&.positive?

              @log << "#{name} train downgraded to a #{base}-train (#{corp.name})"

              # Rename the train to the plain number and set its distances accordingly.
              train.name = base.to_s
              train.distance = [
                { 'nodes' => ['town'],          'pay' => 99,       'visit' => 99 },
                { 'nodes' => %w[city offboard], 'pay' => base,     'visit' => base },
              ]
            end
          end
        end

        def event_cert_limit_change!
          removed = []

          @corporations.reject(&:ipoed).reject(&:closed?).each do |corporation|
            removed << corporation.name
            @corporations.delete(corporation)
            company = company_by_id(corporation.name)
            @companies.delete(company)
            @cert_limit -= 1
          end

          return if removed.empty?

          @log << '-- Event: Removing unopened corporations --'
          @log << "#{list_with_and(removed)} #{removed.one? ? 'is' : 'are'} removed from the game"
          @log << "-- Event: Certificate limit adjusted to #{@cert_limit} --"
        end

        def event_issue_reserve_shares!
          reserve_shares = @corporations.filter_map do |corporation|
            next if !corporation.ipoed || !corporation.share_price

            share = reserved_share_for(corporation)
            share if share&.owner == corporation
          end
          return if reserve_shares.empty?

          @log << '-- Event: Remaining reserve shares are issued to the Market --'
          reserve_shares.each do |share|
            share.buyable = true
            share_pool.transfer_shares(ShareBundle.new(share), share_pool, allow_president_change: false)
          end
        end

        def event_remove_non_corporate_companies!
          privates = @companies.select do |company|
            company.meta[:type] == :private && !company.owner&.corporation? && !company.closed?
          end
          concessions = @companies.select do |company|
            company.meta[:type] == :concession && !company.closed?
          end

          unless privates.empty?
            @log << '-- Event: Non-corporation-owned private companies are removed from the game --'
            @log << "#{list_with_and(privates.map(&:name))} #{privates.one? ? 'is' : 'are'} removed from the game"
            privates.each(&:close!)
          end

          return if concessions.empty?

          @log << '-- Event: Concessions are removed from the game --'
          @log << "#{list_with_and(concessions.map(&:name))} " \
                  "#{concessions.one? ? 'is' : 'are'} removed from the game"
          concessions.each(&:close!)
        end

        def event_ic_formation!
          @log << '-- Event: Illinois Central Formation --'
          move_development_pool_to_auction_pool!
          move_player_privates_to_auction_pool! if draft_style_private_reset?
          @mergeable_candidates = mergeable_corporations
          @log << if @mergeable_candidates.any?
                    present_mergeable_candidates(@mergeable_candidates).to_s
                  else
                    'IC forms with no merger'
                  end

          ic_setup
          option_cube_exchange

          finalize_ic_formation_if_ready!
        end

        def move_development_pool_to_auction_pool!
          privates = @companies.select do |company|
            company.meta[:type] == :private && company.owner.nil? && !company.closed?
          end
          return if privates.empty?

          @log << "#{list_with_and(privates.map(&:name))} moved from the Development Pool to the Auction Pool"
        end

        def move_player_privates_to_auction_pool!
          privates = @players.flat_map do |player|
            player.companies.select { |company| company.meta[:type] == :private && !company.closed? }.each do |company|
              player.companies.delete(company)
              company.owner = nil
            end
          end
          return if privates.empty?

          @log << "#{list_with_and(privates.map(&:name))} moved from player holdings to the Auction Pool"
        end

        # ---------------- IC FORMATION ----------------------
        def ic_setup
          ic.add_ability(self.class::STOCK_PURCHASE_ABILITY)
          ic.add_ability(self.class::TRAIN_BUY_ABILITY)
          ic.add_ability(self.class::TRAIN_LIMIT_ABILITY)
          ic.remove_ability(self.class::FORMATION_ABILITY)
          assign_port_icon(ic)

          market_bundle = ShareBundle.new(ic.shares.last(5))
          @share_pool.transfer_shares(market_bundle, @share_pool)
          ic.shares.each { |share| share.buyable = share.owner == @share_pool }

          stock_market.set_par(ic, @stock_market.par_prices.find do |p|
            p.price == IC_STARTING_PRICE
          end)
          @bank.spend(IC_STARTING_PRICE * 5, ic)
          @merge_share_prices = [ic.share_price.price] # adds IC's share price to array to be averaged later
          @log << "#{ic.name} starts at an #{format_currency(IC_STARTING_PRICE)} share price and " \
                  "receives #{format_currency(IC_STARTING_PRICE * 5)} from the bank"

          place_home_token(ic)
        end

        def option_cube_exchange
          # Exchange option cubes for IC shares from the Market at a rate of 2:1.
          @corporations.each do |corp|
            cubes = @option_cubes[corp] || 0
            next if cubes < 2

            max_pool = @share_pool.shares_of(ic).size
            exchanges = [cubes.div(2), max_pool].min
            next if exchanges.zero?

            exchanges.times do
              bundle = ShareBundle.new(@share_pool.shares_of(ic).last)
              @share_pool.transfer_shares(bundle, corp)
            end

            used_cubes = exchanges * 2
            @option_cubes[corp] = cubes - used_cubes
            @option_cubes.delete(corp) if @option_cubes[corp].zero?

            cube_phrase  = "#{used_cubes} option cubes"
            share_phrase = exchanges == 1 ? 'a 10% share' : "#{exchanges} 10% shares"
            @log << "#{corp.name} exchanges #{cube_phrase} for #{share_phrase} of #{ic.name}"
          end

          # Remove any option cube remaining on a closed corporation.
          @corporations.reject(&:ipoed).each do |corp|
            if @option_cubes.delete(corp)
              @bank.spend(40, corp)
              @log << "#{corp.name} (closed) sells 1 option cube for #{format_currency(40)}"
            end
          end

          # Corporations with one cube choose to receive $40 or pay $40 for a share.
          @exchange_choice_corps = @corporations
            .select { |corp| @option_cubes[corp] == 1 }
            .sort_by { |c| -c.share_price.price }
          @exchange_choice_corp = @exchange_choice_corps.first

          # Automatically resolve one-cube corporations that cannot exchange.
          resolve_auto_one_cube_sales!
        end

        def resolve_auto_one_cube_sales!
          return unless @exchange_choice_corps&.any?

          cost = ic.share_price.price / 2
          # Automatically sell if no Market shares are available or the corporation cannot afford the exchange.
          auto_sell = @exchange_choice_corps.select do |corp|
            ic.num_market_shares.zero? || corp.cash < cost
          end

          auto_sell.each { |corp| option_sell(corp) }

          # Remove automatically sold corporations from the choice queue and set the next decider.
          @exchange_choice_corps -= auto_sell
          @exchange_choice_corp = @exchange_choice_corps.first

          # Try to finish formation if that emptied the queue.
          finalize_ic_formation_if_ready! if @exchange_choice_corps.empty?
        end

        def option_exchange(corp)
          cost = ic.share_price.price / 2
          corp.spend(cost, @bank)
          bundle = ShareBundle.new(@share_pool.shares_of(ic).last)
          @share_pool.transfer_shares(bundle, corp)
          @log << "#{corp.name} pays #{format_currency(cost)} and exchanges 1 option cube " \
                  "for a 10% share of #{ic.name}"
          @option_cubes[corp] -= 1
        end

        def option_sell(corp)
          refund = ic.share_price.price / 2
          refund_str = format_currency(refund)

          @log << if ic.num_market_shares.positive? && corp.cash < refund
                    "#{corp.name} sells 1 option cube for #{refund_str} (insufficient cash to exchange)"
                  elsif ic.num_market_shares.positive?
                    "#{corp.name} sells 1 option cube for #{refund_str}"
                  else
                    "#{corp.name} sells 1 option cube for #{refund_str} (#{ic.name} has no market shares to exchange)"
                  end

          @bank.spend(refund, corp)
          @option_cubes[corp] -= 1
        end

        def decline_merge(corporation)
          @log << "#{corporation.name} declines to merge"
          @mergeable_candidates.delete(corporation)
          finalize_ic_formation_if_ready! if @mergeable_candidates.empty?
        end

        def merge_decider
          @mergeable_candidates.first
        end

        def mergeable_candidates
          @mergeable_candidates ||= []
        end

        def mergeable_corporations
          ic_line_corporations = []
          IC_LINE_CITY_HEXES.each do |hex_id|
            hex = hex_by_id(hex_id)
            @corporations.each do |corp|
              next if ic_line_corporations.include?(corp) ||
                      corp == ic ||
                      @closed_corporations.include?(corp) ||
                      @insolvent_corporations.include?(corp) ||
                      !corp.ipoed

              next unless corp.tokens.any? { |token| token.used && token.hex == hex }

              ic_line_corporations << corp
            end
          end
          ic_line_corporations
        end

        def present_mergeable_candidates(mergeable_candidates)
          items = mergeable_candidates.map do |c|
            controller_name = c.player.name
            "#{c.name} (#{controller_name})"
          end

          "Merge candidate#{'s' unless items.size == 1}: #{list_with_and(items)}"
        end

        def merge_corporation_part_one(corporation = nil)
          @merged_corps << corporation
          @operated_mergees << corporation if operated_this_round?(corporation)
          @mergeable_candidates.delete(corporation)
          @merged_corporation = corporation
          @log << "-- #{corporation.name} merges into #{ic.name} --"

          idx = @round.entities.index(corporation)
          @merged_min_entity_index = [@merged_min_entity_index, idx].compact.min

          price = corporation.share_price.price
          @merge_share_prices << price

          @half_price = (price / 2.0).floor
          @merge_president_player = corporation.owner
          @merge_player_share_bundles = {}

          @players.each do |player|
            shares = player.shares_of(corporation).reject { |s| s&.president }
            next if shares.empty?

            @merge_player_share_bundles[player] = ShareBundle.new(shares)
          end

          market_shares = @share_pool.shares_of(corporation).reject { |s| s&.president }
          @merge_market_share_count = market_shares.size

          @exchange_choice_player = @players.find do |p|
            p.shares_of(corporation).any? { |sh| sh&.president }
          end
        end

        def presidency_exchange(player)
          share = ic.shares_of(ic).reject(&:president).last
          raise GameError, "No 10% shares of #{ic.name} are available" unless share

          bundle = ShareBundle.new(share)
          @log << "#{player.name} receives a 10% share of #{ic.name} for merging #{@merged_corporation.name}"
          @share_pool.transfer_shares(bundle, player)
        end

        def presidency_sell(player)
          refund = @merged_corporation.share_price.price
          @bank.spend(refund, player)
          @log << "#{player.name} receives #{format_currency(refund)} for merging #{@merged_corporation.name}"
        end

        def no_outstanding_non_president_shares?
          market = @merge_market_share_count.to_i
          player = (@merge_player_share_bundles || {}).values.sum { |b| b.shares.size }
          (market + player).zero?
        end

        def merge_corporation_part_two
          corporation = @merged_corporation
          price       = corporation.share_price.price
          half_price  = @half_price || (price / 2.0).floor

          # Sell any IC certificates held by the merging corporation.
          ic_shares = corporation.shares_of(ic)
          if ic_shares&.any?
            ic_bundle = ShareBundle.new(ic_shares)
            ic_sale   = ic_bundle.shares.size * ic.share_price.price
            @log << "#{corporation.name} sells #{ic_bundle.shares.size} " \
                    "share#{'s' unless ic_bundle.shares.size == 1} of #{ic.name} for #{format_currency(ic_sale)}"
            @share_pool.transfer_shares(ic_bundle, @share_pool)
            @bank.spend(ic_sale, corporation)
          end

          if no_outstanding_non_president_shares?
            @log << "#{corporation.name} has no outstanding non-president shares to redeem"
          else
            @log << "#{corporation.name} redeems its ordinary shares"

            (@merge_player_share_bundles || {}).each do |player, bundle|
              share_count = bundle.shares.size
              next if share_count.zero?

              president_shares = player == @merge_president_player
              amount = share_count * (president_shares ? half_price : price)
              pay_merger_redemption(corporation, player, amount)
              @log << "#{player.name} receives #{format_currency(amount)} " \
                      "(#{share_count} ordinary share#{'s' unless share_count == 1} at " \
                      "#{president_shares ? 'half' : 'full'} price)"
            end

            market_shares = @merge_market_share_count.to_i
            if market_shares.positive?
              @log << "#{market_shares} open market share#{'s' unless market_shares == 1} " \
                      "#{market_shares == 1 ? 'is' : 'are'} redeemed without payment"
            end
          end
          # Replace the IC Line token with an IC token.
          ic.tokens << Token.new(ic, price: 0)
          ic_tokens = ic.tokens.reject(&:city)
          corporation_token = corporation.tokens.find { |t| IC_LINE_CITY_HEXES.include?(t&.hex&.id) }
          replace_ic_token(corporation, corporation_token, ic_tokens)

          # Transfer any remaining cash to IC.
          if corporation.cash.positive?
            amt = corporation.cash
            @log << "#{ic.name} receives #{format_currency(amt)} from #{corporation.name}"
            corporation.spend(amt, ic)
          end

          # Transfer trains to IC and clear their operated flags.
          if corporation.trains.any?
            transferred = transfer(:trains, corporation, ic)
            transferred.each { |t| t.operated = false }

            names = transferred.map do |train|
              train.name.length == 1 ? "#{train.name}-train" : "#{train.name} train"
            end

            @log << "#{ic.name} receives #{list_with_and(names)} from #{corporation.name}"
          end

          close_corporation(corporation)
          check_ic_presidency_after_merge!

          finalize_ic_formation_if_ready! if @mergeable_candidates.empty?
        end

        def pay_merger_redemption(corporation, player, amount)
          corporation_payment = [corporation.cash, amount].min
          bank_payment = amount - corporation_payment

          corporation.spend(corporation_payment, player) if corporation_payment.positive?
          @bank.spend(bank_payment, player) if bank_payment.positive?
        end

        def check_ic_presidency_after_merge!
          return unless ic_in_receivership?
          return unless ic.presidents_share.owner == ic

          player = @players.find { |p| p.shares_of(ic).count { |share| !share.president } >= 2 }
          return unless player

          ordinary_shares = player.shares_of(ic).reject(&:president).first(2)
          ordinary_shares.each { |share| share.buyable = false }

          @share_pool.transfer_shares(ShareBundle.new(ordinary_shares), ic, allow_president_change: false)
          ic.presidents_share.buyable = true
          @share_pool.transfer_shares(ShareBundle.new(ic.presidents_share), player)

          if (president_proxy = company_by_id('ICP'))
            @companies.delete(president_proxy)
            president_proxy.close!
          end

          sync_ic_operating_state!
          @log << "#{player.name} exchanges two 10% shares of #{ic.name} for the president's certificate"
        end

        def replace_ic_token(corporation, corporation_token, ic_tokens)
          city = corporation_token.city
          @log << "#{corporation.name}'s token in #{city.hex.name} (#{city.hex.tile.location_name}) " \
                  "is replaced with an #{ic.name} token"
          ic_replacement = ic_tokens.first
          corporation_token.remove!
          city.place_token(ic, ic_replacement, free: true, check_tokenable: false)
          ic_tokens.delete(ic_replacement)
        end

        def ic_reserve_tokens
          @slot_open = true
          count = ic.tokens.count(&:city) - 1

          # A cheater token placed on a full yellow city will move into IC's reserved slot when that city
          # upgrades to green, so it ceases to occupy an additional slot after the upgrade.
          # Place tokens in the city until IC has two.
          while count < 2
            # Add a new token to the corporation.
            ic.tokens << Token.new(ic, price: 0)
            ic_tokens = ic.tokens.reject(&:city)

            # Determine where to place the token.
            hex = ic_line_token_location
            city = hex.tile.cities.first
            city.place_token(ic, ic_tokens.first, free: true, check_tokenable: false, cheater: !@slot_open)

            # Log the token placement.
            @log << "#{ic.name} places a token on #{city.hex.name} (#{hex.tile.location_name})"

            count += 1
          end

          ic.tokens << Token.new(ic, price: 0) while ic.tokens.count < 7
        end

        def ic_line_token_location
          # Try to find an available token slot on the IC Line.
          selected_hexes = find_available_ic_line_city_hexes

          # If no hex is available, find the first city without an IC token.
          if selected_hexes.empty?
            selected_hexes = find_available_ic_line_city_hexes(cheater: true)
            @slot_open = false
          else
            @slot_open = true
          end

          # Return the northernmost available city.
          selected_hexes.last
        end

        def find_available_ic_line_city_hexes(cheater: false)
          hexes.select do |hex|
            IC_LINE_CITY_HEXES.include?(hex.id) && hex.tile.cities.any? do |city|
              !city.tokened_by?(ic) && city.tokenable?(ic, free: true, cheater: cheater)
            end
          end
        end

        def operated_this_round?(entity)
          return false unless entity&.corporation?

          entity.operating_history.include?([@turn, @round.round_num])
        end

        def finalize_ic_formation_if_ready!
          return unless @ic_formation_pending
          return if @mergeable_candidates&.any?
          return if @exchange_choice_corps&.any?
          return if @exchange_choice_player

          post_ic_formation
          @ic_formation_pending = nil
          @log << '-- Event: Illinois Central Formation complete --'
        end

        def post_ic_formation
          ic_reserve_tokens

          train = @depot.upcoming[0]
          if ic.trains.empty?
            @log << "#{ic.name} is trainless"
            ic_needs_train!
            if ic.cash >= @depot.min_depot_price
              train_type = train.name.length == 1 ? "#{train.name}-train" : "#{train.name} train"
              @log << "#{ic.name} buys a #{train_type} for #{format_currency(train.price)} from the Depot"
              ic_owns_train!
              buy_train(ic, train, train.price)
              @phase.buying_train!(ic, train, train.owner)
            else
              @log << "#{ic.name} does not have enough cash to purchase a train"
            end
          end

          if @merge_share_prices.size > 1
            avg_price = @merge_share_prices.sum / @merge_share_prices.count
            ic_new_share_price = @stock_market.market.first.max_by { |p| p.price <= avg_price ? p.price : 0 }
            @log << "#{ic.name}'s new share price is #{format_currency(ic_new_share_price.price)}"
            ic.share_price.corporations.delete(ic)
            stock_market.set_par(ic, ic_new_share_price)
          end

          sync_ic_operating_state!
          assign_ic_operator! if ic_in_receivership?

          ic.floatable = true
          ic.floated   = true
          ic.ipoed     = true
          ic.trains.sort_by!(&:price)

          unoperated_entities = @round.entities.select { |c| !c.closed? && !operated_this_round?(c) }

          # If a merged corporation already operated, IC waits until the next OR.
          if @merged_corps.any? && @operated_mergees.any?
            @log << 'IC will operate for the first time in the next operating round (a merged corporation has already operated)'
            next_entity = unoperated_entities.first
          else
            # IC operates this OR.
            @log << if @merged_corps.any?
                      'IC will operate for the first time in this operating round ' \
                        '(no merged corporations have operated in this round)'
                    else
                      'IC will operate for the first time in this operating round (no corporations merged)'
                    end

            # Find the corporation with the highest stock price below IC's stock price.
            entity_for_insert = unoperated_entities.find { |e| e.share_price.price < ic.share_price.price }

            if entity_for_insert
              @round.entities.insert(@round.entities.index(entity_for_insert), ic)
            else
              @round.entities << ic
            end

            next_entity = @round.entities.find { |c| !c.closed? && !operated_this_round?(c) }
            @round.entity_index = @round.entities.index(next_entity) - 1 if next_entity
          end
          round.entity_index = @round.entities.index(next_entity) - 1 if next_entity
        end

        def sync_ic_operating_state!
          ic.remove_ability(self.class::RECEIVERSHIP_ABILITY)
          ic.remove_ability(self.class::OPERATING_ABILITY)
          if ic_in_receivership?
            ic.add_ability(self.class::RECEIVERSHIP_ABILITY)
          else
            ic.add_ability(self.class::OPERATING_ABILITY)
          end
        end

        def assign_ic_operator!
          queue  = @round.entities
          ic_idx = queue.index(ic) || 0

          prev_owner =
            if ic_idx.positive?
              prev = (ic_idx - 1).downto(0).map { |i| queue[i] }
                            .find { |e| e.corporation? && e.ipoed }
              prev&.owner
            end

          ic.owner = prev_owner || @players.min_by { rand }

          @log << "While in receivership, #{ic.name} will be operated by a random player (#{ic.owner.name})"
        end

        def ic_in_receivership?
          ic.presidents_share.owner == ic
        end
      end
    end
  end
end
