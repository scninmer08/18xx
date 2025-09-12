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

        attr_accessor :stl_nodes, :blocking_token, :exchange_choice_player, :exchange_choice_corp,
                      :exchange_choice_corps, :sp_used, :borrowed_trains, :train_borrowed, :closed_corporations,
                      :other_train_pass, :corporate_buy, :emr_active, :pending_rusting_event, :last_set_pending,
                      :lots, :lot_proxies

        attr_reader :merged_corporation, :last_set, :ic_line_completed_hexes, :insolvent_corporations, :reserved_share

        TRACK_RESTRICTION = :permissive
        SELL_BUY_ORDER = :sell_buy
        TILE_RESERVATION_BLOCKS_OTHERS = :always
        CURRENCY_FORMAT_STR = '$%s'
        BANK_CASH = 99_999
        CAPITALIZATION = :incremental
        CERT_LIMIT = { 2 => 24, 3 => 18, 4 => 15, 5 => 13, 6 => 11 }.freeze
        STARTING_CASH = { 2 => 780, 3 => 540, 4 => 420, 5 => 360, 6 => 300 }.freeze
        TOKEN_COST = 40

        EVENTS_TEXT = Base::EVENTS_TEXT.merge(
          'signal_end_game' => ['Signal End Game', 'Game ends 3 ORs after purchase of first D train'],
        ).freeze

        STATUS_TEXT = Base::STATUS_TEXT.merge(
          'pullman_strike' => ['Pullman Strike (after end of next OR)', '4+2P and 5+1P trains are downgraded to 4- and 5-trains'],
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
        TOWN_HEXES = %w[C2 D9 D13 D17 E6 E14 E16 F5 F13 F21 G22 H11].freeze
        CLASS_A_COMPANIES = %w[].freeze
        CLASS_B_COMPANIES = %w[].freeze
        STL_HEXES = %w[B15 B17 C16 C18].freeze
        STL_TOKEN_HEX = ['C18'].freeze
        CHICAGO_HEX = ['H3'].freeze
        SPRINGFIELD_HEX = ['E12'].freeze
        CORPORATION_SIZES = { 2 => :small, 5 => :medium, 10 => :large }.freeze
        IC_STARTING_PRICE = 80.freeze
        IC_LINE_HEXES = %w[H7 G10 F17 E22].freeze
        BOOM_HEXES = %w[E8 E12].freeze
        GALENA_HEX = %w[C2].freeze
        PORT_ICON = 'port'.freeze
        PORT_MARKER_COST = 40

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
          train_types: %w[2 3 4 4+2P 5+1P 6 D],
          description: 'Must borrow train',
          desc_detail: 'While trainless, IC must borrow the cheapest-available train from the Depot when running trains.'
        )
        RECEIVERSHIP_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Modified oper. turn (receivership)',
          desc_detail: 'IC only performs the "run trains" and "buy trains" steps during '\
                       'its operating turns while in receivership.'
        )
        OPERATING_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Modified operating turn',
          desc_detail: 'IC only performs the "lay track", "place token", "scrap trains", "run trains", '\
                       ' and "buy trains" steps during its operating turns.'
        )
        TRAIN_BUY_ABILITY = Ability::TrainBuy.new(
          type: 'train_buy',
          description: 'Modified train buy',
          desc_detail: 'IC can only buy and sell trains at face value. '\
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
          description: 'Modified stock purchase',
          desc_detail: 'IC treasury shares are only available for purchase in concession rounds.'
        )
        FORMATION_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Unavailable until IC Formation',
          desc_detail: 'IC is unavailable until the IC Formation, which occurs immediately after the operating turn '\
                       ' of the corporation that completes the IC Line.'
        )

        IC_TRAINLESS_ABILITIES = [
          self::FORCED_WITHHOLD_ABILITY,
          self::IMMOBILE_SHARE_PRICE_ABILITY,
          self::BORROW_TRAIN_ABILITY,
        ].freeze

        def next_round!
          @round =
            case @round
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
                new_concession_round
              end
            when init_round.class
              init_round_finished
              new_stock_round
            end
        end

        def concession_round
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

        def operating_round(round_num)
          if intro_game?
            G18IL::Round::Operating.new(self, [
              Engine::Step::Exchange,
              G18IL::Step::SpecialTrack,
              Engine::Step::SpecialToken,
              Engine::Step::HomeToken,
              G18IL::Step::ExchangeChoiceCorp,
              G18IL::Step::ExchangeChoicePlayer,
              G18IL::Step::Merge,
              Engine::Step::DiscardTrain,
              G18IL::Step::Conversion,
              G18IL::Step::PostConversionShares,
              G18IL::Step::BuyNewTokens,
              G18IL::Step::IssueShares,
              G18IL::Step::SpecialBuy,
              G18IL::Step::Track,
              G18IL::Step::Token,
              G18IL::Step::BorrowTrain,
              G18IL::Step::CorporateSellShares,
              G18IL::Step::Route,
              G18IL::Step::Dividend,
              G18IL::Step::SpecialBuyTrain,
              G18IL::Step::BuyTrain,
              [G18IL::Step::BuyCompany, { blocks: true }],
            ], round_num: round_num)
          else
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
              G18IL::Step::SpecialIssueShares,
              G18IL::Step::IssueShares,
              G18IL::Step::SpecialBuy,
              G18IL::Step::Track,
              G18IL::Step::Token,
              G18IL::Step::BorrowTrain,
              G18IL::Step::CorporateSellShares,
              G18IL::Step::BuyTrainBeforeRunRoute,
              G18IL::Step::Route,
              G18IL::Step::Dividend,
              G18IL::Step::SpecialBuyTrain,
              G18IL::Step::BuyTrain,
              [G18IL::Step::BuyCompany, { blocks: true }],
            ], round_num: round_num)
          end
        end

        def tile_lays(entity)
          return super if intro_game?

          if engineering_mastery&.owner == entity
            lays = [{ lay: true, upgrade: true, cost: 0, cannot_reuse_same_hex: true }]

            lays << if @round.upgraded_track
                      { lay: true, upgrade: true, cost: 20, upgrade_cost: 30, cannot_reuse_same_hex: true }
                    else
                      { lay: true, upgrade: true, cost: 20, cannot_reuse_same_hex: true }
                    end

            lays
          elsif efficient_engineering&.owner == entity
            [
              { lay: true, upgrade: true, cost: 0 },
              { lay: true, upgrade: :not_if_upgraded, cost: 10, cannot_reuse_same_hex: true },
            ]
          else
            super
          end
        end

        def company_closing_after_using_ability(company, silent = false)
          @log << "#{company.name} (#{company.owner.name}) closes" unless silent
        end

        def status_array(corp)
          status = []
          company = @companies.find { |c| c.sym == corp.name }
          status << "Concession: #{company.owner.name}" if company&.owner&.player?
          status << "Option cubes: #{@option_cubes[corp]}" if (@option_cubes[corp]).positive?
          status << "Loan amount: #{format_currency(corp.loans.first.amount)}" unless corp.loans.empty?
          status << 'Has not operated' if !corp.operated? && corp.floated?
          status.empty? ? nil : status
        end

        def init_round
          new_concession_round
        end

        def new_concession_round
          @log << "-- Concession Round #{@turn} --"
          concession_round
        end

        def can_par?(corporation, entity)
          return false unless concession_ok?(entity, corporation)

          super
        end

        def ic
          @ic ||= corporation_by_id('IC')
        end

        def concession_ok?(player, corp)
          return false unless player.player?

          player.companies.any? { |c| c.sym == corp.name }
        end

        def return_concessions!
          companies.select { |company| company.meta[:type] == :concession }.each do |c|
            next unless c&.owner&.player?

            player = c.owner
            player.companies.delete(c)
            c.owner = nil
            @log << "The #{c.sym} concession has not been used by #{player.name} and has been returned"
          end
        end

        def finish_stock_round
          return_concessions!

          return if !ic_in_receivership? || !ic_formation_triggered?

          floated_corps = @corporations.select(&:floated)

          index_corp = floated_corps.sort.find { |c| c.share_price.price < ic.share_price.price } if floated_corps.size > 1

          ic.owner = index_corp ? index_corp.owner : @players.min_by { rand }
          @log << "#{ic.name} is in receivership and will be operated "\
                  "by a random player (#{ic.owner.name})"
        end

        def initial_auction_companies
          companies
        end

        def company_status_str(company)
          return if company.owner
          return unless company.meta[:type] == :concession
          return if @companies.none? { |c| c.meta[:type] == :private }

          corp = @corporations.find { |c| c.name == company.sym }
          return if corp.nil? || corp.companies.none?

          a = corp.companies[0]
          b = corp.companies[1]

          # Build initial string
          parts = []
          parts << a.name.to_s if a
          parts << ' | ' if a && b
          parts << b.name.to_s if b
          result = parts.join

          # Abbreviate if needed to keep the status on one line
          if result.length > 38
            abbreviations = {
              'Goodrich Transit Line' => 'GTL',
              'Illinois Steel Bridge Co.' => 'IL Steel Bridge Co.',
              'Chicago-Virden Coal Co.' => 'C-V Coal Co.',
              'Union Stock Yards' => 'USY',
            }

            abbreviations.each do |long, short|
              if result.include?(long)
                result = result.gsub(long, short)
                break
              end
            end
          end

          result
        end

        def company_header(company)
          return 'CONCESSION LOT' if lots_variant? && @turn == 1

          case company.meta[:type]
          when :share then 'ORDINARY SHARE'
          when :presidents_share then "PRESIDENT'S SHARE"
          when :concession then 'CONCESSION'
          end
        end

        def corporation_size(entity)
          # change stock market token size based on share count of corporation
          CORPORATION_SIZES[entity.total_shares]
        end

        def corporation_size_name(entity)
          entity.total_shares.to_s
        end

        def float_str(_entity)
          '2 shares to start'
        end

        def nc
          @nc ||= corporation_by_id('NC')
        end

        def ic_formation_triggered?
          @ic_formation_triggered
        end

        def stlbc
          @stl_blocking_corp
        end

        def find_company_by_name(name)
          @companies.find { |c| c&.name == name }
        end

        def optional_hexes
          return game_hexes unless intro_game?

          hexes = game_hexes

          hexes[:white].delete(GALENA_HEX)
          hexes[:yellow][GALENA_HEX] = 'town=revenue:30;path=a:1,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=G'
          hexes[:red][['B3']] = 'label=W;offboard=revenue:yellow_30|brown_40,groups:West;path=a:4,b:_0;path=a:0,b:_0;'\
                                'border=edge:0;border=edge:5'
          hexes
        end

        def setup_preround
          super

          # Create and initialize the blocking corporation for placing blocking tokens in STL
          create_blocking_corp

          # Set up corporations for intro game or regular game setup
          initial_auction_lot unless intro_game?
          setup_lots if lots_variant?
          @log << "Northern Cross Railroad starts with the 'Rogers' (1+1) train"
        end

        # Create the corporation that places blocking tokens in St. Louis
        def create_blocking_corp
          # Initialize the blocking corporation with its logos and tokens
          @stl_blocking_corp = Corporation.new(
            sym: 'STLBC', name: 'stl_blocking_corp', logo: BLOCKING_LOGOS[0],
            simple_logo: BLOCKING_LOGOS[0], tokens: [0]
          )
          @stl_blocking_corp.owner = @bank

          # Find the city where the blocking tokens will be placed
          city = @hexes.find { |hex| hex.id == 'C18' }.tile.cities.first

          # Place blocking tokens in the city for each color
          BLOCKING_LOGOS.each do |logo|
            token = Token.new(@stl_blocking_corp, price: 0, logo: logo, simple_logo: logo, type: :blocking)
            city.place_token(@stl_blocking_corp, token, check_tokenable: false)
          end
        end

        def fixed_setup?
          optional_rules&.include?(:fixed_setup)
        end

        def intro_game?
          optional_rules&.include?(:intro_game)
        end

        def lots_variant?
          optional_rules&.include?(:lots_variant) && two_player?
        end

        def two_player_share_limit?
         # optional_rules&.include?(:two_player_share_limit) && two_player?
          two_player?
        end

        # Set up corporations for auction lot formation in the regular game
        def initial_auction_lot
          class_a = @companies.select { |c| c.meta[:class] == :A }
          class_b = @companies.select { |c| c.meta[:class] == :B }
          class_a = class_a.sort_by { rand } unless fixed_setup?
          class_b = class_b.sort_by { rand } unless fixed_setup?

          @log << '-- Auction Lot Formation --'
          @corporations.select(&:floatable).each_with_index do |corp, index|
            [class_a, class_b].each do |class_list|
              company = class_list[index]
              company.owner = corp
              corp.companies << company
            end
            @log << "#{class_a[index].name} and #{class_b[index].name} assigned to #{corp.name} concession"
          end
        end

        def setup_lots
          @log << '-- Lots Formation --'

          bucket = @corporations.select(&:floatable).group_by(&:total_shares)

          # Always randomize corp order for lot formation (independent of fixed_setup)
          ten_shares  = bucket[10].sort_by { rand }
          five_shares = bucket[5].sort_by { rand }
          two_shares  = bucket[2].sort_by { rand }

          @lots = Array.new(2) do
            [ten_shares.shift, five_shares.shift, five_shares.shift, two_shares.shift].compact
          end

          @lots.each_with_index do |lot, idx|
            names = list_with_and(lot.map(&:name))
            @log << "#{names} concessions are assigned to Lot #{idx + 1}"
          end
          @lot_proxies = [make_lot_company(0), make_lot_company(1)]
          @companies |= @lot_proxies
        end

        def make_lot_company(idx)
          names = list_with_and(@lots[idx].map(&:name))

          Engine::Company.new(
            sym: "BL#{idx + 1}",
            name: "Lot #{idx + 1}",
            value: 10,
            revenue: 0,
            desc: "Contains #{names}",
            color: '#333333',
            text_color: 'white',
            abilities: [],
            meta: { type: :lot, lot_index: idx },
          )
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
            when 'Rogers (1+1)'
              help << "The 'Rogers' train may only run a route from Springfield to Jacksonville."
            when '3P'
              help << "A 3P train can visit three cities, doubling their value. It may not visit red areas."
            when '4+2P'
              help << "A 4+2P train can visit six cities or red areas, doubling the value of two cities."
            when '5+1P'
              help << "A 5+1P train can visit six cities or red areas, doubling the value of one city."
            when 'D'
              help << "A D train can visit an unlimited number of stops."
            end
          end

          help.uniq
        end

        def setup
          # Dynamically creates methods for each private company (i.e., station_subsidy)
          @companies.each do |c|
            if c.meta[:type] == :private
              method_name = c.name.downcase.gsub(/[^a-z0-9]+/, '_').gsub(/^_|_$/, '')
              self.class.send(:define_method, method_name) { c }
            end
          end

          ic.add_ability(self.class::FORMATION_ABILITY)
          ic.owner = nil
          @corporation_debts = Hash.new { |h, k| h[k] = 0 }
          # @train_bought_this_or = false
          @insolvent_corporations = []
          @last_set_pending = nil
          @last_set = nil
          @ic_president = nil
          @ic_owns_train = false
          @ic_formation_triggered = nil
          @closed_corporations = []
          @train_borrowed = nil
          @borrowed_trains = {}
          @merged_corps = []
          @ic_trigger_entity = nil
          @emr_active = nil
          @ic_formation_pending = false
          @option_cubes ||= Hash.new(0)
          @ic_line_completed_hexes = []
          @merge_share_prices = []

          # Northern Cross starts with the 'Rogers' train
          train = @depot.upcoming[0]
          train.buyable = false
          buy_train(nc, train, :free)

          @corporations.select { |corp| corp.type == :two_share }.each { |c| c.max_ownership_percent = 100 }

          if !intro_game? && (share_premium&.owner&.total_shares == 10)
            @reserved_share = share_premium&.owner&.ipo_shares&.last
            @reserved_share.buyable = false
          end

          @stl_nodes = STL_HEXES.map do |h|
            hex_by_id(h).tile.nodes.find { |n| n.offboard? && n.groups.include?('STL') }
          end

          if intro_game?
            # Removes 838 tile and G1 tile
            @all_tiles.each { |tile| tile.hide if tile.name == 'G1' || tile.name == '838' }
          else
            # Deletes gray Springfield and Peoria tiles
            @gray_boom_tiles = []
            @gray_boom_tiles.concat(tiles.select { |tile| tile.name == 'P4' || tile.name == 'S4' })
            tiles.delete_if { |tile| tile.name == 'P4' || tile.name == 'S4' }
          end

          #   apply_cbot_for!(chicago_board_of_trade&.owner) unless intro_game?
        end

        def ipo_name(_entity = nil)
          'Treasury'
        end

        def ipo_verb(_entity = nil)
          'starts'
        end

        def ipo_reserved_name(_entity = nil)
          'Reserve'
        end

        def setup_optional_rules
          return unless @optional_rules

          # If players could check both “one extra” and “two extra”, combine them safely:
          add_optional_train('3',  (@optional_rules.include?(:one_extra_three_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_three_trains) ? 2 : 0))
          add_optional_train('4',  (@optional_rules.include?(:one_extra_four_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_four_trains) ? 2 : 0))
          add_optional_train('4+2P',(@optional_rules.include?(:one_extra_four_plus_two_p_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_four_plus_two_p_trains) ? 2 : 0))
          add_optional_train('5+1P',(@optional_rules.include?(:one_extra_five_plus_one_p_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_five_plus_one_p_trains) ? 2 : 0))
          add_optional_train('6',  (@optional_rules.include?(:one_extra_six_train) ? 1 : 0) +
                                  (@optional_rules.include?(:two_extra_six_trains) ? 2 : 0))
        end

        def add_optional_train(type, count)
          return if count <= 0

          proto = self.class::TRAINS.find { |e| e[:name] == type }
          raise GameError, "Unknown train type: #{type}" unless proto

          # how many of this type already exist (for the stack index shown as e.g. 3(3))
          base_stack_index = @depot.trains.count { |t| t.name == type }

          # where to insert in upcoming: after the last of this type, else by roster order
          last_same_idx = @depot.upcoming.rindex { |t| t.name == type }
          if last_same_idx
            insert_base = last_same_idx + 1
          else
            roster_order = self.class::TRAINS.map { |t| t[:name] }
            target_pos   = roster_order.index(type) || roster_order.length
            insert_base = @depot.upcoming.index { |t|
              (roster_order.index(t.name) || roster_order.length) > target_pos
            } || @depot.upcoming.length
          end

          count.times do |i|
            new_train = Train.new(**proto, index: base_stack_index + i)
            @depot.insert_train(new_train, insert_base + i)
          end

          # Usually not needed because Depot#insert_train clears its cache,
          # but keep this if your engine requires it:
          update_cache(:trains)
        end


        def emr_active?
          @emr_active
        end

        def owns_port_marker?(corporation)
          return true if corporation.assignments.include?(PORT_ICON)

          false
        end

        def assign_port_icon(corp)
          corp.assign!(PORT_ICON)
        end

        def rust_trains!(train, entity)
          ic_needs_train! if entity == ic && ic.trains.empty?
          return super if intro_game? || !po_can_save_rusting_train?(train)

          @pending_rusting_event = { train: train, entity: entity }
        end

        def po_can_save_rusting_train?(purchased_train)
          !@pending_rusting_event &&
            (owner = planned_obsolescence.owner) &&
            owner.corporation? &&
            owner.trains.any? { |t| rust?(t, purchased_train) }
        end

        def company_sellable(company); end

        def upgrades_to?(from, to, special = false, selected_company: nil)
          # P4 and S4 are available in intro game, but only available to Central Illinois Boom in normal game
          if !intro_game? && BOOM_HEXES.include?(from.hex.id)
            if selected_company != central_il_boom || phase.name != 'D'
              return false if to.name == 'P4' || to.name == 'S4'
            else
              case from.hex.id
              when 'E8'
                return to.name == 'P4'
              when 'E12'
                return to.name == 'S4'
              end
            end
          end

          return true if !intro_game? && TOWN_HEXES.include?(from.hex.id) &&
          to.name == '838' && selected_company == chicago_virden_coal_co

          super
        end

        def tile_valid_for_phase?(tile, hex: nil, phase_color_cache: nil)
          return true if tile.name == '838'

          super
        end

        def eligible_tokens?(corporation)
          corporation.tokens.find { |t| t.used && !STL_TOKEN_HEX.include?(t.hex.id) }
        end

        def place_home_token(corporation)
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
          # if reopened corp has flipped token(s) on map, it can flip one of these tokens (except for STL)
          if eligible_tokens?(corporation)
            hexes.select { |hex| hex.tile.cities.find { |c| c.tokened_by?(corporation) && !STL_TOKEN_HEX.include?(hex.id) } }
          else
            # otherwise, it can place token in any available city slot except in CHI or STL
            hexes.select do |hex|
              hex.tile.cities.any? { |c| c.tokenable?(corporation) } &&
              !STL_TOKEN_HEX.include?(hex.id) && !CHICAGO_HEX.include?(hex.id)
            end
          end
        end

        def update_ic_abilities!(add:)
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
          @mergeable_candidates&.delete(corporation)
          @option_cubes.delete(corporation) if (@option_cubes[corporation] || 0).positive?

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

            @round.entity_index = [[@round.entity_index, @round.entities.size - 1].min, 0].max
          end

          # un-IPO the corporation
          corporation.share_price&.corporations&.delete(corporation)
          corporation.share_price = nil
          corporation.par_price = nil
          corporation.ipoed = false
          corporation.unfloat!

          # sell owned shares of IC to market
          corporation.cash += corporation.shares_of(ic).size * ic.share_price.price if corporation.shares_of(ic)&.any?

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

          # return shares to IPO
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

          # flip all of the corporation's tokens on the map; remove Union Stock Yards token
          corporation.tokens.each do |token|
            next unless token.used

            if token.extra
              token.remove!
            else
              token.status = :flipped
            end
          end

          # home location is removed
          corporation.coordinates = nil

          # reactivate concession
          company = company_by_id(corporation.name)
          company.owner = nil
          @companies << company
          @companies = @companies.sort

          close_corporations_in_close_cell!
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

          trigger_ic_formation(action)
        end

        def complete_ic_line_for(hex, icons, corp)
          @ic_line_completed_hexes << hex

          icons.each do |icon|
            next unless icon.sticky

            icons.delete(icon)
            @option_cubes[corp] += 1
            @log << "#{corp.name} receives an option cube"
          end
        end

        def log_ic_line_progress
          @log << "IC Line hexes completed: #{@ic_line_completed_hexes.size} of 10"
        end

        def trigger_ic_formation(action)
          if phase.name == 'D'
            @log << 'IC Line is complete, but does not form in phase D'
          else
            @log << 'IC Line is complete'
            @log << "-- The Illinois Central Railroad will form at the end of #{action.entity.name}'s turn --"
            @ic_formation_triggered = true
            @ic_formation_pending = true
            @ic_trigger_entity = action.entity
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

        def path_to_city(paths, edge)
          paths.find { |p| p.exits == [edge] }
        end

        def ic_line_completed?
          @ic_line_completed_hexes.size == IC_LINE_COUNT
        end

        def remove_icon(hex, icon_names)
          icon_names.each do |name|
            icons = hex.tile.icons
            icons.reject! { |i| name == i.name }
            hex.tile.icons = icons
          end
        end

        def corporation_opts
          two_player_share_limit? ? { max_ownership_percent: 70 } : {}
        end

        def convert(corporation)
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
          corporation.max_ownership_percent = two_player_share_limit? ? 70 : 60
          shares.each { |share| corporation.share_holders[share.owner] += share.percent }
          new_shares.each { |share| add_new_share(share) }

          if !intro_game? && corporation == share_premium.owner && corporation.total_shares == 10
            @reserved_share = share_premium&.owner&.ipo_shares&.last
            @reserved_share.buyable = false
          end
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
          @timeline = [
            'End of OR 1.1: All unsold 2-trains are exported.',
            'End of each subsequent OR: The next-available train is exported', \
            '*Exported trains are removed from the game and can trigger phase changes as if purchased',
          ].freeze
        end

        def purchase_tokens!(corporation, count, total_cost, quiet = false)
          count.times { corporation.tokens << Token.new(corporation, price: 0) }
          auto_emr(corporation, total_cost) if corporation.cash < total_cost
          if !intro_game? && corporation == station_subsidy.owner
            @log << "#{corporation.name} uses #{station_subsidy.name} and buys"\
                    " #{count} #{count == 1 ? 'token' : 'tokens'} for #{format_currency(total_cost)}"
            token_ability = corporation.all_abilities.find { |a| a.desc_detail == 'Station Subsidy' }
            count.times { token_ability.use! }
            unless token_ability.count.positive?
              station_subsidy.close!
              @log << "#{station_subsidy.name} (#{corporation.name}) closes"
            end
          else
            corporation.spend(total_cost, @bank)
            unless quiet
              @log << "#{corporation.name} buys #{count} #{count == 1 ? 'token' : 'tokens'} for #{format_currency(total_cost)}"
            end
          end
        end

        # sell IPO shares to make up shortfall
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
          if !intro_game? && corporation == share_premium.owner &&
            @round.steps.find do |step|
              step.instance_of?(G18IL::Step::SpecialIssueShares)
            end&.active?
            all_bundles.each do |b|
              b.share_price = corporation.share_price.price * 2.0
            end
          # halves the value of corporate-held shares if EMRing
          elsif @round.steps.find do |step|
                  step.instance_of?(G18IL::Step::CorporateSellShares)
                end&.active? &&
            !@round.steps.find do |step|
               step.instance_of?(G18IL::Step::IssueShares)
             end&.active? &&
             share_holder.is_a?(Corporation)
            all_bundles.each do |b|
              b.share_price = corporation.share_price.price / 2.0 if corporation != ic
            end
          end
          all_bundles.concat(partial_bundles_for_presidents_share(corporation, bundle, percent)) if shares.last.president

          all_bundles.sort_by(&:percent)
        end

        def sell_shares_and_change_price(bundle, allow_president_change: true, swap: nil, movement: nil)
          corporation = bundle.corporation
          if (emr_active? && bundle.owner == corporation) || corporation.share_price.price == lowest_stock_price
            movement = :down_share
          end
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
          return 0 if corporation.trains.any? || @other_train_pass

          emergency_issuable_bundles(corporation).max_by(&:num_shares)&.price || 0
        end

        def emergency_issuable_bundles(entity)
          return [] unless entity.cash < @depot.min_depot_price
          return [] unless entity.corporation?
          return [] if entity.num_ipo_shares.zero?

          # @emr_active = true
          bundles = bundles_for_corporation(entity, entity)
          bundles.each { |b| b.share_price = entity.share_price.price / 2.0 }
          eligible, remaining = bundles.partition { |bundle| bundle.price + entity.cash < @depot.min_depot_price }
          remaining.empty? ? [eligible.last].compact : [remaining.first].compact
        end

        def issuable_shares(entity)
          return [] unless entity.corporation?
          return [] if entity.num_treasury_shares.zero?

          bundles_for_corporation(entity, entity).take(1)
        end

        def borrow_train(action)
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

        def city_tokened_by?(city, entity)
          return false unless entity&.corporation?
          return false unless city.respond_to?(:tokens)

          # normal slots
          return true if city.tokens.any? { |t| t&.corporation == entity && t.status != :flipped }

          # extra slots (if present)
          city.respond_to?(:extra_tokens) &&
            city.extra_tokens.any? { |t| t&.corporation == entity && t.status != :flipped }
        end

        def export_train
          if phase.name == '2'
            depot.export_all!('2')
            nc.trains.shift
            @log << '-- Event: Rogers (1+1) train rusts --'
            phase.next!
          # elsif !@train_bought_this_or && phase.name != 'D'
          elsif phase.name != 'D'
            depot.export!
          elsif phase.name == 'D'
            @last_set_pending = true
          end
          # @train_bought_this_or = false
        end

        def or_round_finished
          # buy_train will disallow cross-train buys in final OR before final cycle
          @last_set_pending = true if phase.name == 'D'
        end

        def or_set_finished
          # no one owns IC if in receivership
          ic.owner = nil if ic_in_receivership?

          # convert unstarted corporations at the appropriate time.
          if %w[4A 4B 5 6 D].include?(@phase.name)
            @corporations.each do |c|
              # Convert only if not floated and not closed
              if !c.floated? && !@closed_corporations.include?(c)
                convert(c) if c.total_shares == 2
                convert(c) if c.total_shares == 5 && @phase.name != '4A'
              end

              # update the attached company's share_count (including closed corps)
              if (company = @companies.find { |comp| comp.sym == c.name })
                company.meta[:share_count] = c.total_shares
              end
            end
          end

          return unless phase.name == 'D'

          # remove unopened corporations and decrement cert limit
          remove_unparred_corporations!

          @log << "-- Event: Certificate limit adjusted to #{@cert_limit} --"

          # Pullman Strike
          @log << '-- Event: Pullman Strike --'
          event_pullman_strike!
          @last_set = true
        end

        def init_stock_market
          stock_market = G18IL::StockMarket.new(self.class::MARKET, [], zigzag: :flip)
          stock_market.game = self
          stock_market
        end

        def p_bonus(route, stops)
          return 0 unless route.train.name.end_with?('P')

          # Exclude offboard/edge cities even if implemented as city parts
          offboard_groups = %w[West East North South STL]
          cities = stops.select { |s| s.city? && (s.groups & offboard_groups).empty? }
          return 0 if cities.empty?

          # Use the number right before 'P' (e.g., "4+2P" => 2, "3P" => 3)
          m = route.train.name.match(/(\d+)P$/)
          count = m ? m[1].to_i : 0
          return 0 if count.zero?

          cities.map { |stop| stop.route_revenue(route.phase, route.train) }
                .max([count, cities.size].min)
                .sum
        end

        def ew_ns_bonus(stops)
          bonus = { revenue: 0 }

          east = stops.find { |stop| stop.groups.include?('East') }
          west = stops.find { |stop| stop.groups.include?('West') }
          north = stops.find { |stop| stop.groups.include?('North') }
          south = stops.find { |stop| stop.groups.include?('South') }

          if east && west
            bonus[:revenue] = 80
            bonus[:description] = 'E/W'
          end

          if north && south
            bonus[:revenue] = 100
            bonus[:description] = 'N/S'
          end

          bonus
        end

        def routes_subsidy(routes)
          routes.sum(&:subsidy)
        end

        # Pays $20 to the corp that owns FWC when a train visits Galena
        def pay_fwc_bonus!(routes, entity)
          return if !frink_walker_co || frink_walker_co.closed?

          return unless routes.any? { |r| r.hexes.any? { |h| GALENA_HEX.include?(h.id) } }

          return if entity == frink_walker_co.owner

          @bank.spend(20, frink_walker_co.owner)
          @log << "#{frink_walker_co.owner.name} receives a subsidy of #{format_currency(20)} "\
                  'from the bank (Frink, Walker, & Co.)'
        end

        def subsidy_for(route, _stops)
          return 0 if intro_game? || route.corporation != u_s_mail_line.owner

          city_stops(route).count * 10
        end

        def revenue_for(route, stops)
          revenue = super
          revenue += ew_ns_bonus(stops)[:revenue] + p_bonus(route, stops)
          revenue
        end

        def revenue_str(route)
          str = super
          bonus = ew_ns_bonus(route.stops)[:description]
          str += " + #{bonus}" if bonus
          str
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
          raise GameError, 'Train cannot visit St. Louis without a permit token' unless stl_permit?(current_entity)
        end

        def check_three_p(route, visits)
          return unless route.train.name == '3P'
          raise GameError, 'Cannot visit red areas' if visits.first.tile.color == :red || visits.last.tile.color == :red
        end

        def check_rogers(route, visits)
          return unless route.train.name == 'Rogers (1+1)'
          if (visits.first.hex.name == 'E12' && visits.last.hex.name == 'D13') ||
            (visits.last.hex.name == 'E12' && visits.first.hex.name == 'D13')
            return
          end

          raise GameError, "'Rogers' train can only run between Springfield and Jacksonville"
        end

        def check_port(route, visits)
          return if visits.none? { |v| PORT_HEXES.find { |h| v.hex == hex_by_id(h) } } || owns_port_marker?(route.corporation)

          raise GameError, 'Corporation must own a port marker to visit a port'
        end

        def check_distance(route, visits)
          # checks STL for permit token
          check_stl(visits)

          # disallows 3P trains from running to red areas
          check_three_p(route, visits)

          # disallows Rogers train from running outside of Springfield/Jacksonville
          check_rogers(route, visits)

          # disallows corporations without a port token from running to a port
          check_port(route, visits)

          super
        end

        def init_loans
          # this is only used for view purposes
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
          corporation.cash += loan

          if insolvent_corporations.include?(corporation)
            @log << "#{corporation.name} adds #{format_currency(loan)} to its existing loan"
            corporation.loans.first.amount += loan
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

          corporation.loans.shift
          remaining_loan = loan_balance - payoff_amount
          corporation.loans << Loan.new(corporation, remaining_loan)
          corporation.cash -= payoff_amount

          if remaining_loan.zero?
            @log << "#{corporation.name} pays off its loan of #{format_currency(loan_balance)}"
            @log << "-- #{corporation.name} is now solvent --"
            @insolvent_corporations.delete(corporation)
            corporation.loans.clear
          else
            @log << "#{corporation.name} decreases its loan by #{format_currency(payoff_amount)} "\
                    "(#{format_currency(remaining_loan)} remaining)"
          end
        end

        def round_description(name, round_number = nil)
          return 'Concession Round' if name == 'Auction'

          super
        end

        def event_signal_end_game!
          # Play one more OR, then Pullman Strike and blocking token events occur, then play one final set (CR, SR, 3 ORs)
          @final_operating_rounds = 3
          @last_set_triggered = true
          game_end_check
          @operating_rounds = 3 if phase.name == 'D' && round.round_num == 2
          @log << "-- First D train bought, game ends at the end of OR #{@turn + 1}.#{@final_operating_rounds} --"
          @log << "-- At the end of OR #{@turn}.#{@round.round_num + 1}, 4+2P and 5+1P trains will downgrade to "\
                  '4- and 5-trains --'
          @log << '-- Pullman Strike: Blocking tokens will be placed in the home locations of unopened corporations --'
          tiles.concat(@gray_boom_tiles) unless intro_game?
        end

        def remove_unparred_corporations!
          @blocking_log = []
          @removed_corp_log = []

          @corporations.reject(&:ipoed).reject(&:closed?).each do |corporation|
            place_home_blocking_token(corporation) if corporation.coordinates
            @removed_corp_log << corporation.name
            @corporations.delete(corporation)
            company = company_by_id(corporation.name)
            @companies.delete(company)
            @cert_limit -= 1
          end

          @log << if @blocking_log.empty?
                    '-- Event: Removing unopened corporations --'
                  else
                    '-- Event: Removing unopened corporations and placing blocking tokens --'
                  end

          @log << "#{list_with_and(@removed_corp_log)} #{@removed_corp_log.count == 1 ? 'is' : 'are'} removed from the game"

          return nil if @blocking_log.empty?

          @log << "Blocking #{@blocking_log.count == 1 ? 'token' : 'tokens'} placed on #{list_with_and(@blocking_log)}"
        end

        def place_home_blocking_token(corporation)
          cities = []

          hex = hex_by_id(corporation.coordinates)
          if hex.tile.reserved_by?(corporation)
            cities.concat(hex.tile.cities)
          else
            cities << hex.tile.cities.find { |city| city.reserved_by?(corporation) }
            cities.first.remove_reservation!(corporation)
          end
          cities.each do |city|
            @blocking_log << "#{hex.name} (#{hex.location_name})"
            city ||= hex.tile.cities[0]
            # token = Token.new(corporation, price: 0, logo: "/logos/18_il/#{corporation.name}.svg",
            #                                simple_logo: "/logos/18_il/#{corporation.name}.alt.svg", type: :blocking)
            token = Token.new(corporation, price: 0, logo: "/logos/18_il/#{corporation.name}.alt.svg",
                                           simple_logo: "/logos/18_il/#{corporation.name}.alt.svg", type: :blocking)
            token.status = :flipped
            city.place_token(corporation, token, check_tokenable: false)
          end
        end

        def final_operating_rounds
          @final_operating_rounds || super
        end

        # Pullman Strike: 4+2P and 5+1P trains downgrade to 4- and 5-trains, respectively.
        def event_pullman_strike!
          @corporations.each do |c|
            c.trains.each do |train|
              next unless train.name.include?('P')

              # pull out the numeric part (e.g., "3P" -> 3)
              base_num = train.name[/\d+/].to_i

              @log << "#{train.name} train downgraded to a #{base_num}-train (#{c.name})"

              # rename to the plain number (as a string) and set numeric distances
              train.name = base_num.to_s
              train.distance = [
                { 'nodes' => %w[town],             'pay' => 99,        'visit' => 99 },
                { 'nodes' => %w[city offboard],    'pay' => base_num,  'visit' => base_num },
              ]
            end
          end
        end

        def process_single_action(action)
          corp = action.entity.owner if action.entity.company?
          super

          return if intro_game?

          if action.entity == goodrich_transit_line
            assign_port_icon(corp)
            log << "#{corp.name} receives a port marker"
          end

          return unless action.entity == central_il_boom

          tile = action.hex.tile
          tile_to_remove = case tile.name
                           when 'P4' then 'S4'
                           when 'S4' then 'P4'
                           end

          @log << "Tile ##{tile_to_remove} is removed from the game"
          tiles.delete_if { |t| t.name == tile_to_remove }
        end

        def redeemable_shares(entity)
          return [] unless entity.corporation?
          return [] unless @round.steps.find { |step| step.is_a?(G18IL::Step::BaseBuySellParShares) }.active?

          bundles_for_corporation(share_pool, entity)
            .reject { |bundle| entity.cash < bundle.price }
        end

        def event_ic_formation!
          @log << '-- Event: Illinois Central Formation --'

          @mergeable_candidates = mergeable_corporations

          @log << if @mergeable_candidates.any?
                    present_mergeable_candidates(@mergeable_candidates).to_s
                  else
                    'IC forms with no merger'
                  end

          ic_setup

          option_cube_exchange

          post_ic_formation if @mergeable_candidates.empty?
        end

        def ic_setup
          ic.add_ability(self.class::STOCK_PURCHASE_ABILITY)
          ic.add_ability(self.class::TRAIN_BUY_ABILITY)
          ic.add_ability(self.class::TRAIN_LIMIT_ABILITY)
          ic.remove_ability(self.class::FORMATION_ABILITY)
          assign_port_icon(ic)

          bundle = ShareBundle.new(ic.shares.last(5))
          @share_pool.transfer_shares(bundle, @share_pool)
          ic.shares.each do |s|
            s.buyable = false
          end

          stock_market.set_par(ic, @stock_market.par_prices.find do |p|
            p.price == IC_STARTING_PRICE
          end)
          @bank.spend(IC_STARTING_PRICE * 10, ic)
          @merge_share_prices = [ic.share_price.price] # adds IC's share price to array to be averaged later
          @log << "#{ic.name} starts at an #{format_currency(IC_STARTING_PRICE)} share price and "\
                  "receives #{format_currency(IC_STARTING_PRICE * 10)} from the bank"

          place_home_token(ic)
        end

        def option_cube_exchange
          # option cubes are exchanged for IC shares from the market at a rate of 2:1
          @corporations.each do |corp|
            cubes = (@option_cubes[corp] || 0)
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

          # Corps with exactly 1 cube left choose: receive $40 or pay $40 for a share
          @exchange_choice_corps = @corporations.select { |corp| @option_cubes[corp] == 1 }.sort
          @exchange_choice_corp  = @exchange_choice_corps.first
        end

        def option_exchange(corp)
          cost = ic.share_price.price / 2
          corp.spend(cost, @bank)
          bundle = ShareBundle.new(@share_pool.shares_of(ic).last)
          @share_pool.transfer_shares(bundle, corp)
          @log << "#{corp.name} pays #{format_currency(cost)} and exchanges 1 option cube "\
                  "for a 10% share of #{ic.name}"
          @option_cubes[corp] -= 1
        end

        def option_sell(corp)
          refund = ic.share_price.price / 2
          @bank.spend(refund, corp)
          @log << if ic.num_market_shares.positive?
                    "#{corp.name} sells 1 option cube for #{format_currency(refund)}"
                  else
                    "#{corp.name} sells 1 option cube for #{format_currency(refund)} "\
                      "(#{ic.name} has no market shares to exchange)"
                  end
          @option_cubes[corp] -= 1
        end

        def decline_merge(corporation)
          @log << "#{corporation.name} declines to merge"
          @mergeable_candidates.delete(corporation)
          post_ic_formation if @mergeable_candidates.empty?
        end

        def merge_decider
          @mergeable_candidates.first
        end

        def mergeable_candidates
          @mergeable_candidates ||= []
        end

        def mergeable_corporations
          ic_line_corporations = []
          4.times do |i|
            corp = @corporations.find { |c| c.tokens.find { |t| t.hex == hex_by_id(IC_LINE_HEXES[i]) } }
            next if corp.nil? ||
                    corp == ic ||
                    @closed_corporations.include?(corp) ||
                    @insolvent_corporations.include?(corp) ||
                    !corp.ipoed

            ic_line_corporations << corp
          end
          ic_line_corporations.uniq
        end

        def present_mergeable_candidates(mergeable_candidates)
          items = mergeable_candidates.map do |c|
            controller_name = c.player.name
            "#{c.name} (#{controller_name})"
          end

          "Merge candidate#{items.size == 1 ? '' : 's'}: #{list_with_and(items)}"
        end

        def merge_corporation_part_one(corporation = nil)
          @merged_corps << corporation
          @mergeable_candidates.delete(corporation)
          @merged_corporation = corporation
          @log << "-- #{corporation.name} merges into #{ic.name} --"

          price = corporation.share_price.price
          @merge_share_prices << price

          @half_price = (price / 2.0).floor
          @merge_president_player = corporation.owner
          @merge_player_share_bundles = {}

          player_share_total = 0
          @players.each do |player|
            shares = player.shares_of(corporation).reject { |s| s&.president }
            next if shares.empty?

            @merge_player_share_bundles[player] = ShareBundle.new(shares)
            player_share_total += shares.size
          end

          market_shares = @share_pool.shares_of(corporation).reject { |s| s&.president }
          @merge_market_share_count = market_shares.size

          share_total   = player_share_total + @merge_market_share_count
          @total_refund = share_total * @half_price

          @exchange_choice_player = @players.find do |p|
            p.shares_of(corporation).any? { |sh| sh&.president }
          end
        end

        def presidency_exchange(player)
          bundle = ShareBundle.new(ic.shares_of(ic).last)
          @log << "#{player.name} exchanges the president's share of #{@merged_corporation.name} for a 10% share of #{ic.name}"
          @share_pool.transfer_shares(bundle, player)
        end

        def presidency_sell(player)
          refund = @merged_corporation.share_price.price
          @bank.spend(refund, player)
          @log << "#{player.name} sells the president's share of #{@merged_corporation.name} for #{format_currency(refund)}"
        end

        def merge_corporation_part_two
          corporation = @merged_corporation
          price       = corporation.share_price.price
          half_price  = @half_price || (price / 2.0).floor

          # Sell any IC certificates held by the merging corporation
          ic_shares = corporation.shares_of(ic)
          if ic_shares&.any?
            ic_bundle = ShareBundle.new(ic_shares)
            ic_sale   = ic_bundle.shares.size * ic.share_price.price
            @log << "#{corporation.name} sells #{ic_bundle.shares.size} "\
                    "share#{'s' unless ic_bundle.shares.size == 1} of #{ic.name} for #{format_currency(ic_sale)}"
            @share_pool.transfer_shares(ic_bundle, @share_pool)
            corporation.cash += ic_sale
          end

          # Can the corporation redeem at half price?
          sufficient = corporation.cash >= @total_refund

          if sufficient
            @log << "#{corporation.name} will redeem outstanding shares at half price"
          else
            @log << "#{corporation.name} lacks sufficient funds to redeem outstanding shares at half price. "\
                    "Its treasury (#{format_currency(corporation.cash)}) is returned to the bank"
            @log << 'The bank guarantees redemption of shares held by players other than the president at full value'
            corporation.spend(corporation.cash, @bank) if corporation.cash.positive?
          end

          # Redeem market shares
          if corporation.cash.positive? && @merge_market_share_count.positive?
            market_amount = @merge_market_share_count * half_price
            corporation.spend(market_amount, @bank)
          end
          # Redeem player shares
          (@merge_player_share_bundles || {}).each do |player, bundle|
            share_count = bundle.shares.size
            next if share_count.zero?

            if sufficient
              amount = share_count * half_price
              corporation.spend(amount, player)
              @log << "#{player.name} receives #{format_currency(amount)} from #{corporation.name}"
            elsif player != @merge_president_player
              amount = share_count * price
              @bank.spend(amount, player)
              @log << "#{player.name} receives #{format_currency(amount)} from the bank"
            end
          end
          @log << "The bank receives #{format_currency(market_amount)} from #{corporation.name}" if market_amount

          # Replace the IC-Line station with an IC marker
          ic.tokens << Token.new(ic, price: 0)
          ic_tokens = ic.tokens.reject(&:city)
          corporation_token = corporation.tokens.find { |t| IC_LINE_HEXES.include?(t&.hex&.id) }
          replace_ic_token(corporation, corporation_token, ic_tokens)

          # Transfer any remaining cash to IC
          if corporation.cash.positive?
            amt = corporation.cash
            @log << "#{ic.name} receives the #{corporation.name} treasury of #{format_currency(amt)}"
            corporation.spend(amt, ic)
          end

          # Transfer trains to IC (clear operated flags)
          if corporation.trains.any?
            transferred = transfer(:trains, corporation, ic)
            transferred.each { |t| t.operated = false }

            names = transferred.map do |train|
              train.name.length == 1 ? "#{train.name}-train" : "#{train.name} train"
            end

            @log << "#{ic.name} receives #{list_with_and(names)} from #{corporation.name}"
          end

          post_ic_formation if @mergeable_candidates.empty?
        end

        def replace_ic_token(corporation, corporation_token, ic_tokens)
          city = corporation_token.city
          @log << "#{corporation.name}'s token in #{city.hex.name} (#{city.hex.tile.location_name}) "\
                  "is replaced with an #{ic.name} token"
          ic_replacement = ic_tokens.first
          corporation_token.remove!
          city.place_token(ic, ic_replacement, free: true, check_tokenable: false)
          ic_tokens.delete(ic_replacement)
        end

        def ic_reserve_tokens
          @slot_open = true
          count = ic.tokens.count(&:city) - 1

          # Place tokens in the city until we have 2
          while count < 2
            # Add new token to the corporation
            ic.tokens << Token.new(ic, price: 0)
            ic_tokens = ic.tokens.reject(&:city)

            # Determine where to place the token
            hex = ic_line_token_location
            city = hex.tile.cities.first
            city.place_token(ic, ic_tokens.first, free: true, check_tokenable: false, cheater: !@slot_open)

            # Log the token placement
            @log << "#{ic.name} places a token on #{city.hex.name} (#{hex.tile.location_name})"

            count += 1
          end

          ic.tokens << Token.new(ic, price: 0) while ic.tokens.count < 6
        end

        def ic_line_token_location
          # Try to find an available token slot on the IC Line
          selected_hexes = find_available_ic_line_hexes

          # If no available hexes found, look for the first city without an IC token
          if selected_hexes.empty?
            selected_hexes = find_available_ic_line_hexes(cheater: true)
            @slot_open = false
          else
            @slot_open = true
          end

          # Return the northernmost available city
          selected_hexes.last
        end

        def find_available_ic_line_hexes(cheater: false)
          hexes.select do |hex|
            IC_LINE_HEXES.include?(hex.id) && hex.tile.cities.any? do |city|
              !city.tokened_by?(ic) && city.tokenable?(ic, free: true, cheater: cheater)
            end
          end
        end

        def operated_this_round?(corporation)
          return unless @round.operating?

          order = @round.entities.index(corporation)
          idx = @round.entities.index(@round.current_entity)
          order < idx if order && idx
        end

        def post_ic_formation
          ic_reserve_tokens

          train = @depot.upcoming[0]
          if ic.trains.empty? && ic.cash >= @depot.min_depot_price
            @log << "#{ic.name} is trainless"
            ic_needs_train!
            train_type = train.name.length == 1 ? "#{train.name}-train" : "#{train.name} train"
            @log << "#{ic.name} buys a #{train_type} for #{format_currency(train.price)} from the Depot"
            ic_owns_train!
            buy_train(ic, train, train.price)
            @phase.buying_train!(ic, train, train.owner)
          end

          if @merge_share_prices.size > 1
            price = @merge_share_prices.sum / @merge_share_prices.count
            ic_new_share_price = @stock_market.market.first.max_by { |p| p.price <= price ? p.price : 0 }
            @log << "#{ic.name}'s new share price is #{format_currency(ic_new_share_price.price)}"
            ic.share_price.corporations.delete(ic)
            stock_market.set_par(ic, ic_new_share_price)
          end

          add_ic_receivership_ability
          if ic_in_receivership?
            @log << "#{ic.name} enters receivership (it has no president)"
            ic_price = ic.share_price&.price
            live = @round.entities.select { |c| c.corporation? && c.share_price && !c.closed? }
            index_corp = live.sort.find { |c| c.share_price.price < ic_price } || live.min_by { |c| c.share_price.price }
            ic.owner = index_corp ? index_corp.owner : @players.min_by { rand }
            @log << "While in receivership, #{ic.name} will be operated by a random player (#{ic.owner.name})"
          else
            add_ic_operating_ability
          end

          earliest_index = @merged_corps.empty? ? 99 : @merged_corps.map { |n| @round.entities.index(n) }.min
          current_corp_index = @round.entities.index(@ic_trigger_entity)

          if current_corp_index < earliest_index || @round.entities.empty?
            @log << if @merged_corps.empty?
                      'IC will operate for the first time in this operating round (no corporations merged)'
                    else
                      'IC will operate for the first time in this operating round (no merged corporations '\
                        'have operated in this round)'
                    end
            ic_price = ic.share_price&.price
            live = @round.entities.select { |c| c.corporation? && c.share_price && !c.closed? }
            index_corp = live.sort.find { |c| c.share_price.price < ic_price }
            index = @round.entities.find_index(index_corp)
            if index.nil?
              @round.entities << ic
            else
              trigger_price = @ic_trigger_entity.share_price&.price || 0
              if ic.share_price.price > trigger_price
                @round.entities.insert(current_corp_index + 1, ic)
              else
                @round.entities.insert(index, ic)
              end
            end
          else
            @log << 'IC will operate for the first time in the next operating round (a merged corporation has already operated)'
          end

          ic.floatable = true
          ic.floated = true
          ic.ipoed = true

          @merged_corps.each do |c|
            close_corporation(c)
          end

          @ic_formation_pending = false
          @log << '-- Event: Illinois Central Formation complete --'

          return unless @round.entities.empty?

          @round.entities << ic
          next_round!
        end

        def add_ic_operating_ability
          return if @ic_president == true

          ic.remove_ability(self.class::RECEIVERSHIP_ABILITY)
          ic.add_ability(self.class::OPERATING_ABILITY)
          @ic_president = true
        end

        def add_ic_receivership_ability
          ic.add_ability(self.class::RECEIVERSHIP_ABILITY)
        end

        def ic_in_receivership?
          ic.presidents_share.owner == ic
        end
      end
    end
  end
end
