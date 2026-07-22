# frozen_string_literal: true

require_relative '../base'
require_relative '../cities_plus_towns_route_distance_str'
require_relative 'city'
require_relative 'corporation'
require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative 'round/auction'
require_relative 'round/operating'
require_relative 'stock_market'
require_relative 'step/bankrupt'
require_relative 'step/buy_sell_par_shares'
require_relative 'step/buy_train'
require_relative 'step/buy_tokens'
require_relative 'step/company_pending_par'
require_relative 'step/corporate_action'
require_relative 'step/land_grant_auction'
require_relative 'step/route'
require_relative 'step/special_token'
require_relative 'step/special_track'
require_relative 'step/track_and_token'

module Engine
  module Game
    module G1872
      class Game < Game::Base
        CORPORATION_CLASS = G1872::Corporation

        include_meta(G1872::Meta)
        include CitiesPlusTownsRouteDistanceStr
        include Entities
        include Map

        BANK_CASH = 99_999_999
        CAPITALIZATION = :incremental
        FLOAT_PERCENT = 50
        MUST_BUY_TRAIN = :always
        SELL_BUY_ORDER = :sell_buy
        MUST_EMERGENCY_ISSUE_BEFORE_EBUY = true
        BANKRUPTCY_ENDS_GAME_AFTER = :all_but_one
        GAME_END_CHECK = { bankrupt: :immediate, stock_market: :immediate, mines_connection: :one_more_full_or_set }.freeze
        GAME_END_REASONS_TEXT = Base::GAME_END_REASONS_TEXT.merge(
          mines_connection: 'Colorado Mines is connected to St. Louis or Chicago',
        ).freeze
        GAME_END_DESCRIPTION_REASON_MAP_TEXT = Base::GAME_END_DESCRIPTION_REASON_MAP_TEXT.merge(
          mines_connection: 'Colorado Mines connected to St. Louis or Chicago',
        ).freeze
        EVENTS_TEXT = Base::EVENTS_TEXT.merge(
          'remove_territory_borders' => ['Territory Borders Removed', 'The territory borders are removed from the map'],
        ).freeze
        TOKEN_PRICE = 100

        EW_BONUS = 100
        LAND_GRANT_BID_MARKERS = 2
        EXCLUDED_LAND_GRANT_HEXES = %w[B38 C35 F4 F36 F40 H26 H38 H42 J36 K33].freeze
        COLORADO_MINES_HEX = 'E3'
        EASTERN_CONNECTION_HEXES = %w[B42 H44].freeze

        # Two track actions. Both may be upgrades, including on the same hex.
        TILE_LAYS = [{ lay: true, upgrade: true }, { lay: true, upgrade: true }].freeze

        CERT_LIMIT = { 2 => 28, 3 => 20, 4 => 16, 5 => 13, 6 => 11 }.freeze

        STARTING_CASH = { 2 => 1200, 3 => 800, 4 => 600, 5 => 480, 6 => 400 }.freeze

        MARKET = [
          %w[74 82 90 100 111 122 135 149m 165 182 200 222 246 272 300x 332n 368 408 452 500e],
          %w[67 74 82 90 100 111 122 135m 149 165 182 200x 222 246 272 300n 332 368],
          %w[60 67 74 82 90 100 111 122m 135x 149 165 182 200 222 246 272n],
          %w[53 60 67 74 82 90p 100 111m 122 135 149 165 182 200],
          %w[46 53 60p 67 74 82 90 100m 111 122 135 149],
          %w[39 46 53 60 67 74 82 90m 100 111 122],
          %w[33 39 46 53 60 67 74 82m 90 100],
          %w[27 33 39 46 53 60 67 74m 82],
          %w[21 27 33 39 46 53 60 67m],
          %w[15 21 27 33 39 46 53],
          %w[9 15 21 27 33 39],
          %w[3 9 15 21 27],
        ].freeze

        STOCKMARKET_COLORS = Base::STOCKMARKET_COLORS.merge(
          par_1: :green,
          max_price: :orange,
          max_price_1: :blue,
        ).freeze

        MARKET_TEXT = Base::MARKET_TEXT.merge(
          par_1: 'Par value (Phase 3+)',
          max_price: 'Maximum price before phase 3',
          max_price_1: 'Maximum price before phase 8',
        ).freeze

        PHASES = [
          {
            name: '2',
            train_limit: 4,
            tiles: [:yellow],
            operating_rounds: 1,
          },
          {
            name: '3',
            on: '3',
            train_limit: 4,
            tiles: %i[yellow green],
            operating_rounds: 2,
            status: ['can_buy_companies'],
          },
          {
            name: '4',
            on: '4',
            train_limit: 3,
            tiles: %i[yellow green],
            operating_rounds: 2,
            status: ['can_buy_companies'],
          },
          {
            name: '5',
            on: '5',
            train_limit: 3,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: '6',
            on: '6',
            train_limit: 2,
            tiles: %i[yellow green brown],
            operating_rounds: 3,
          },
          {
            name: '7',
            on: '7',
            train_limit: 2,
            tiles: %i[yellow green brown gray],
            operating_rounds: 3,
          },
          {
            name: '8',
            on: '8+',
            train_limit: 2,
            tiles: %i[yellow green brown gray],
            operating_rounds: 3,
          },
        ].freeze

        TRAINS = [
          { name: '2', distance: 2, price: 80, rusts_on: '4', num: 6 },
          { name: '3', distance: 3, price: 180, rusts_on: '5', num: 5 },
          { name: '4', distance: 4, price: 300, rusts_on: '6', num: 4 },
          {
            name: '5',
            distance: 5,
            price: 450,
            rusts_on: '7',
            num: 3,
          },
          { name: '6', distance: 6, price: 630, num: 2, events: [{ 'type' => 'remove_territory_borders' }] },
          { name: '7', distance: 7, price: 840, num: 1 },
          {
            name: '8+',
            distance: [
              { 'nodes' => ['town'], 'pay' => 99, 'visit' => 99 },
              { 'nodes' => %w[city offboard], 'pay' => 8, 'visit' => 8 },
            ],
            price: 1080,
            num: 99,
          },
        ].freeze

        def stock_round
          Engine::Round::Stock.new(self, [
            Engine::Step::DiscardTrain,
            Engine::Step::Exchange,
            G1872::Step::CompanyPendingPar,
            G1872::Step::SpecialTrack,
            G1872::Step::BuySellParShares,
          ])
        end

        def init_stock_market
          G1872::StockMarket.new(game_market, self.class::CERT_LIMIT_TYPES,
                                 multiple_buy_types: self.class::MULTIPLE_BUY_TYPES, game: self)
        end

        attr_reader :corporations, :land_grants, :pending_token_buys, :shell_parent, :shell_path, :shell_root,
                    :isolated_shell_homes, :land_grant_child

        def setup_preround
          @land_grants = build_land_grants
          @companies.concat(@land_grants)
          @ipo_rows = deal_land_grant_columns(@land_grants.sort_by { rand })
        end

        def setup
          @pending_token_buys = []
          @shell_parent = {}
          @shell_path = {}
          @shell_root = {}
          @shell_child_count = Hash.new(0)
          @isolated_shell_homes = {}
          @land_grant_child = {}
          @mines_connection_needs_update = true
          @mines_connection_reached = false
          add_territory_borders
          place_starting_home_tokens
        end

        def place_starting_home_tokens
          @corporations.each do |corporation|
            next if corporation.type == :shell || corporation.tokens.first&.used

            hex = hex_by_id(corporation.coordinates)
            city = hex.tile.cities.find { |candidate| candidate.reserved_by?(corporation) } || hex.tile.cities.first
            city.place_token(corporation, corporation.find_token_by_type)
          end
        end

        def add_territory_borders
          self.class::TERRITORY_BORDERS.each do |coord, edges|
            hex = hex_by_id(coord)
            edges.each do |edge|
              add_territory_border(hex, edge)
              add_territory_border(hex.neighbors[edge], Hex.invert(edge)) if hex.neighbors[edge]
            end
          end
        end

        def add_territory_border(hex, edge)
          return if hex.tile.borders.any? { |border| border.edge == edge && border.type == :province }

          hex.tile.borders << Part::Border.new(edge, 'province', nil, 'red')
        end

        def event_remove_territory_borders!
          self.class::TERRITORY_BORDERS.each do |coord, edges|
            hex = hex_by_id(coord)
            edges.each do |edge|
              remove_territory_border(hex, edge)
              remove_territory_border(hex.neighbors[edge], Hex.invert(edge)) if hex.neighbors[edge]
            end
          end

          @log << '-- Event: Territory borders are removed --'
        end

        def remove_territory_border(hex, edge)
          hex.tile.borders.reject! { |border| border.edge == edge && border.type == :province }
        end

        def territory_borders_active?
          self.class::TERRITORY_BORDERS.any? do |coord, edges|
            hex = hex_by_id(coord)
            edges.any? { |edge| hex.tile.borders.any? { |border| border.edge == edge && border.type == :province } }
          end
        end

        def calc_border_paths
          border_paths = {}
          @hexes.each do |hex|
            border_edges = hex.tile.borders.select { |border| border.type == :province }.map(&:edge)
            next if border_edges.empty?

            hex.tile.paths.each do |path|
              border_paths[path] = true unless (path.edges.map(&:num) & border_edges).empty?
            end
          end
          border_paths
        end

        def graph_border_paths(_entity)
          calc_border_paths
        end

        def territory_border_connected_to_target?(acquirer, target)
          graph = Graph.new(self, check_regions: true)
          connected = graph.connected_nodes(acquirer).keys
          target.tokens.select(&:used).any? { |token| token.city && connected.include?(token.city) }
        end

        def init_round
          new_auction_round
        end

        def new_auction_round
          Engine::Round::Auction.new(self, [
            G1872::Step::CompanyPendingPar,
            Engine::Step::WaterfallAuction,
          ])
        end

        def next_round!
          @round =
            case @round
            when G1872::Round::Auction
              clear_programmed_actions
              @players.each(&:unpass!)
              new_stock_round
            when Engine::Round::Auction
              init_round_finished
              new_stock_round
            when Engine::Round::Stock
              @operating_rounds = @phase.operating_rounds
              reorder_players
              new_operating_round
            when Engine::Round::Operating
              or_round_finished
              if @round.round_num < @operating_rounds
                new_operating_round(@round.round_num + 1)
              else
                @turn += 1
                or_set_finished
                land_grant_auction_available? ? new_land_grant_auction_round : new_stock_round
              end
            end
        end

        def land_grant_auction_available?
          %w[3 4 5].include?(@phase.name) && @land_grants.any? { |company| company.owner == @bank }
        end

        def bidding_token_per_player
          self.class::LAND_GRANT_BID_MARKERS
        end

        def initial_auction_companies
          @companies.reject { |company| company.type == :land_grant }
        end

        def new_land_grant_auction_round
          @players.each(&:unpass!)
          @log << "-- #{round_description('Auction', 1)} --"
          @round_counter += 1
          G1872::Round::Auction.new(self, [G1872::Step::LandGrantAuction])
        end

        def show_ipo_rows?
          @round.is_a?(G1872::Round::Auction)
        end

        def show_entities_ipo_rows?
          land_grant_ipo_rows.any?(&:any?)
        end

        def ipo_row_title(_ipo_row_number)
          nil
        end

        def ipo_row_companies_title
          'Grants'
        end

        def ipo_rows
          rows = land_grant_ipo_rows
          return rows unless @round.is_a?(G1872::Round::Auction)

          rows.reject { |row| row.size == 1 }
        end

        def land_grant_ipo_rows
          @ipo_rows || []
        end

        def buyable_bank_owned_companies
          return [] if @round.is_a?(G1872::Round::Auction)

          super.reject { |company| company.type == :land_grant }
        end

        def show_value_of_companies?(entity)
          return true if entity == @bank && land_grant_ipo_rows.any?(&:any?)

          super
        end

        def status_array(corp)
          status = []
          status << 'Has not operated' if !corp.operated? && corp.floated?
          status.empty? ? nil : status
        end

        def company_header(company)
          return 'LAND GRANT' if company.type == :land_grant

          super
        end

        def company_status_str(company)
          statuses = Array(land_grant_bid_status(company) || super)
          statuses << 'Used' if land_grant_used?(company)
          statuses.empty? ? nil : statuses
        end

        def land_grant_bid_status(company)
          return if company.type != :land_grant || !@round.is_a?(G1872::Round::Auction)

          step = @round&.steps&.find { |candidate| candidate.is_a?(G1872::Step::LandGrantAuction) }
          bids = step&.bids&.[](company)
          return if bids.nil? || bids.empty?

          bids.map { |bid| "#{bid.entity.name}: #{format_currency(bid.price)}" }
        end

        def remove_land_grant(company)
          @ipo_rows.each { |row| row.delete(company) }
        end

        def remove_connected_unauctioned_land_grants!
          @land_grants.each do |land_grant|
            next unless land_grant.owner == @bank
            next if land_grant.closed?
            next if hex_by_id(land_grant_hex_id(land_grant)).tile.preprinted

            remove_land_grant(land_grant)
            land_grant.close!
            @log << "#{land_grant.name} is removed from the land grant auction"
          end
        end

        def cycle_unauctioned_land_grant_rows(auctioned_row_indices)
          @ipo_rows.each_with_index do |row, index|
            next if auctioned_row_indices.include?(index)
            next if row.size < 2

            cycled_grant = row.shift
            row << cycled_grant
            @log << "#{cycled_grant.name} moves to the bottom of land grant column #{index + 1}"
          end
        end

        def build_land_grants
          land_grant_hexes.map do |hex_id|
            name = LOCATION_NAMES[hex_id] || hex_id
            Company.new(
              sym: "LG-#{hex_id}",
              name: "#{name} (#{hex_id})",
              value: 0,
              revenue: 0,
              desc: "Land grant reservation for #{name} (#{hex_id}).",
              type: :land_grant,
              color: '#76A65D',
            ).tap { |company| company.owner = @bank }
          end
        end

        def land_grant_hexes
          hexes = self.class::HEXES.each_with_object([]) do |(_color, hex_definitions), coords|
            hex_definitions.each do |hex_ids, code|
              coords.concat(Array(hex_ids)) if code.include?('city=')
            end
          end

          (hexes.uniq - self.class::EXCLUDED_LAND_GRANT_HEXES).sort_by do |hex_id|
            [Engine::Hex::LETTERS.index(hex_id.match(Engine::Hex::COORD_LETTER)[1]),
             hex_id.match(Engine::Hex::COORD_NUMBER)[1].to_i]
          end
        end

        def land_grant_column_count
          @players.size + 1
        end

        def deal_land_grant_columns(deck)
          base_size, spare_count = deck.size.divmod(land_grant_column_count)

          land_grant_column_count.times.map do |index|
            deck.shift(base_size + (index < spare_count ? 1 : 0))
          end
        end

        def available_shells
          @corporations.select { |corporation| corporation.type == :shell && !corporation.ipoed }
        end

        def assign_shell_identity(shell, parent)
          raise GameError, 'That corporation is not an available shell' unless available_shells.include?(shell)

          root = @shell_root[parent] || parent
          number = @shell_child_count[parent] += 1
          path = Array(@shell_path[parent]) + [number]
          @shell_parent[shell] = parent
          @shell_path[shell] = path
          @shell_root[shell] = root
          shell.assign_shell_identity!(root, path)
          update_cache(:corporations)
        end

        def corporation_ancestor?(descendant, corporation)
          parent = @shell_parent[descendant]
          while parent
            return true if parent == corporation

            parent = @shell_parent[parent]
          end
          false
        end

        def direct_child?(parent, corporation)
          @shell_parent[corporation] == parent
        end

        def same_genealogy?(corporation, other)
          (@shell_root[corporation] || corporation) == (@shell_root[other] || other)
        end

        def corporation_may_own_shares?(owner, corporation)
          return true unless owner&.corporation?

          owner == corporation || direct_child?(owner, corporation)
        end

        def token_corporation(corporation)
          return corporation unless corporation&.type == :shell
          return corporation if isolated_shell?(corporation)

          @shell_root[corporation] || corporation
        end

        def isolated_shell?(corporation)
          @isolated_shell_homes.key?(corporation)
        end

        def has_isolated_shell_descendant?(corporation)
          @isolated_shell_homes.keys.any? { |shell| corporation_ancestor?(shell, corporation) }
        end

        def land_grant_hex_id(land_grant)
          land_grant.sym.delete_prefix('LG-')
        end

        def land_grant_territory(land_grant)
          territory_for_hex(land_grant_hex_id(land_grant))
        end

        def territory_for_hex(hex_id)
          self.class::LAND_GRANT_TERRITORIES.find { |_territory, hexes| hexes.include?(hex_id) }&.first
        end

        def territory_name(territory)
          territory.to_s.capitalize
        end

        def player_land_grants(player)
          @land_grants.select { |company| company.owner == player && !company.closed? }
        end

        def corporation_land_grants(corporation)
          @land_grants.select { |company| company.owner == corporation && !company.closed? }
        end

        def land_grant_used?(company)
          company&.type == :land_grant && company.instance_variable_get(:@g1872_used)
        end

        def genealogy_land_grant_territory_available?(corporation, land_grant)
          territory = land_grant_territory(land_grant)
          return true unless territory

          !genealogy_has_land_grant_territory?(corporation, territory)
        end

        def genealogy_has_land_grant_territory?(corporation, territory)
          root = @shell_root[corporation] || corporation

          shell_in_territory = @corporations.any? do |candidate|
            next false unless candidate.type == :shell
            next false unless candidate.ipoed
            next false unless (@shell_root[candidate] || candidate) == root

            territory_for_hex(candidate.coordinates) == territory
          end
          return true if shell_in_territory

          @land_grants.any? do |land_grant|
            next false if land_grant.closed?
            next false unless land_grant_territory(land_grant) == territory

            owner = land_grant.owner
            owner&.corporation? && (@shell_root[owner] || owner) == root
          end
        end

        def land_grant_bid_marker_owner(company)
          return unless company&.type == :land_grant

          company.instance_variable_get(:@g1872_bid_marker_owner)
        end

        def assign_land_grant_bid_marker!(company, player)
          return unless company&.type == :land_grant

          company.instance_variable_set(:@g1872_bid_marker_owner, player)
        end

        def return_land_grant_bid_marker!(company)
          return unless company&.type == :land_grant

          company.remove_instance_variable(:@g1872_bid_marker_owner) if
            company.instance_variable_defined?(:@g1872_bid_marker_owner)
        end

        def retained_land_grant_bid_marker_count(player)
          @land_grants.count do |land_grant|
            !land_grant.closed? && land_grant_bid_marker_owner(land_grant) == player
          end
        end

        def mark_land_grant_used!(company)
          return unless company&.type == :land_grant

          company.instance_variable_set(:@g1872_used, true)
        end

        def usable_land_grant?(land_grant, _corporation)
          hex = hex_by_id(land_grant_hex_id(land_grant))
          land_grant_home_city_available?(hex) || land_grant_home_upgrade_tiles(hex).any?
        end

        def place_shell_land_grant_home(shell, sponsor, land_grant, connected: nil)
          hex = hex_by_id(land_grant_hex_id(land_grant))
          city = land_grant_home_city(shell, hex)
          graph.clear_graph_for_all
          connected = land_grant_connected_to_sponsor_network?(sponsor, hex) if connected.nil?
          token = shell_home_token(shell)

          shell.coordinates = hex.id
          land_grant.owner.companies.delete(land_grant) if land_grant.owner.respond_to?(:companies)
          sponsor.companies << land_grant unless sponsor.companies.include?(land_grant)
          land_grant.owner = sponsor
          @land_grant_child[land_grant] = shell
          mark_land_grant_used!(land_grant)
          city.place_token(shell, token, free: true, check_tokenable: false)

          if connected
            assimilate_shell_home!(shell, sponsor)
          else
            token.status = :flipped
            @isolated_shell_homes[shell] = token
            @log << "#{shell.name}'s home station is placed at #{hex.id} and flipped because it is not connected to "\
                    "#{sponsor.name}'s network"
          end

          graph.clear_graph_for_all
        end

        def land_grant_connected_to_sponsor_network?(sponsor, hex)
          sponsor_token_corporation = token_corporation(sponsor)
          graph_for_entity(sponsor_token_corporation).reachable_hexes(sponsor_token_corporation).key?(hex)
        end

        def shell_home_token(shell)
          # Shells normally use their root corporation's token array. An isolated land-grant home is the exception:
          # until it connects, it must be a real shell token so flipping it does not also flip the parent's marker.
          root = @shell_root[shell]
          if root && shell.tokens.equal?(root.tokens)
            shell.instance_variable_set(:@tokens, [])
          else
            shell.tokens.delete_if { |token| !token.used && token.corporation != shell }
          end

          shell.tokens.find { |token| !token.used && token.corporation == shell } ||
            Token.new(shell, price: 0).tap { |token| shell.tokens << token }
        end

        def land_grant_home_city(_corporation, hex)
          return hex.tile.cities.find { |city| city.available_slots.positive? } if land_grant_home_city_available?(hex)

          raise GameError, "#{hex.id} has no available station spot for a land grant home"
        end

        def land_grant_home_city_available?(hex)
          hex.tile.cities.any? { |city| city.available_slots.positive? }
        end

        def land_grant_home_upgrade_tiles(hex)
          old_tile = hex.tile
          old_slots = old_tile.cities.sum(&:normal_slots)

          @tiles.filter_map do |tile|
            next unless tile_valid_for_phase?(tile, hex: hex)
            next unless upgrades_to?(old_tile, tile)
            next unless tile.cities.sum(&:normal_slots) > old_slots

            rotations = Engine::Tile::ALL_EDGES.select do |edge|
              tile.rotate!(edge)
              old_paths_maintained_for_land_grant?(old_tile, tile)
            end
            next if rotations.empty?

            tile.legal_rotations = rotations
            tile.rotate!(rotations.first)
            tile
          end
        end

        def lay_land_grant_home_upgrade!(hex, tile, rotation)
          valid_tile = land_grant_home_upgrade_tiles(hex).find { |candidate| candidate.name == tile.name }
          raise GameError, "Tile ##{tile.name} cannot be used for this land grant home" unless valid_tile
          raise GameError, "Rotation #{rotation} is not legal for tile ##{tile.name} on #{hex.id}" unless
            valid_tile.legal_rotations.include?(rotation)

          old_tile = hex.tile
          tile.rotate!(rotation)
          update_tile_lists(tile, old_tile)
          hex.lay(tile)
          graph.clear_graph_for_all
          @log << "#{hex.id} upgrades from ##{old_tile.name} to ##{tile.name} for its land grant home station"
        end

        def old_paths_maintained_for_land_grant?(old_tile, new_tile)
          old_tile.paths.all? { |path| new_tile.paths.any? { |new_path| path <= new_path } }
        end

        def assimilate_connected_shells!
          @isolated_shell_homes.keys.each do |shell|
            parent = @shell_parent[shell]
            next unless parent
            next unless shell_home_connected_to_parent?(shell, parent)

            assimilate_shell_home!(shell, parent)
          end
        end

        def shell_home_connected_to_parent?(shell, parent = @shell_parent[shell])
          token = @isolated_shell_homes[shell]
          return false unless token&.city
          return false unless parent

          token_graph_for_entity(token_corporation(parent)).connected_nodes(token_corporation(parent)).key?(token.city)
        end

        def assimilate_shell_home!(shell, parent = @shell_parent[shell])
          token = @isolated_shell_homes.delete(shell) || shell.tokens.find(&:used)
          return unless token&.city&.hex
          return unless parent

          token.status = nil
          parent_token_corporation = token_corporation(parent)
          token.corporation = parent_token_corporation
          parent_token_corporation.tokens << token unless parent_token_corporation.tokens.include?(token)
          shell.instance_variable_set(:@tokens, parent_token_corporation.tokens)
          @log << "#{shell.name}'s home station at #{token.hex.id} is connected and assimilated into "\
                  "#{parent.name}'s network"
          graph.clear_graph_for_all
        end

        def city_tokened_by?(city, entity)
          super(city, entity) || (entity.respond_to?(:type) && entity.type == :shell && super(city, token_corporation(entity)))
        end

        def reparent_shell_family(target, acquirer)
          direct_children = shell_children(target)
          return if direct_children.empty?

          new_root = @shell_root[acquirer] || acquirer
          direct_children.each { |shell| reassign_shell_subtree(shell, acquirer, new_root) }

          @shell_parent.delete(target)
          @shell_path.delete(target)
          @shell_root.delete(target)
          @shell_child_count.delete(target)
        end

        def shell_children(parent)
          @shell_parent
            .select { |_shell, shell_parent| shell_parent == parent }
            .keys
            .sort_by { |shell| @corporations.index(shell) || Float::INFINITY }
        end

        def shell_descendants(parent)
          shell_children(parent).flat_map { |child| [child, *shell_descendants(child)] }
        end

        def reassign_shell_subtree(shell, parent, root)
          children = shell_children(shell)
          old_name = shell.name
          number = @shell_child_count[parent] += 1
          path = Array(@shell_path[parent]) + [number]

          @shell_parent[shell] = parent
          @shell_path[shell] = path
          @shell_root[shell] = root
          @shell_child_count[shell] = [@shell_child_count[shell], children.size].compact.max || 0
          shell.owner = parent
          shell.assign_shell_identity!(root, path)
          @log << "#{old_name} becomes #{shell.name} under #{parent.name}" unless old_name == shell.name

          children.each { |child| reassign_shell_subtree(child, shell, root) }
        end

        def can_par?(corporation, entity)
          if corporation.type == :shell
            step = @round&.steps&.find { |candidate| candidate.is_a?(G1872::Step::CorporateAction) }
            return step&.can_par_shell?(corporation, entity) || false
          end

          super
        end

        def corporations_can_ipo?
          step = @round&.active_step
          return false if step.respond_to?(:corporate_issue_shares?) && step.corporate_issue_shares?

          true
        end

        def ipo_name(_entity = nil)
          'Treasury'
        end

        def par_price_gated_until_phase_3?(share_price)
          share_price.type == :par_1 && !@phase.available?('3')
        end

        def all_corporations
          @corporations.reject { |corporation| corporation.type == :shell && !@shell_parent.key?(corporation) }
        end

        def bank_sort(corporations)
          corporations.sort_by do |corporation|
            [corporation.type == :shell ? 1 : 0, @corporations.index(corporation) || Float::INFINITY]
          end
        end

        def player_sort(entities)
          sorted = entities.sort_by do |corporation|
            root = @shell_root[corporation] || corporation
            path = Array(@shell_path[corporation]).map { |number| number || Float::INFINITY }
            [operating_order.index(root) || Float::INFINITY, path.empty? ? 0 : 1, path, corporation.name]
          end
          sorted.group_by { |corporation| acting_for_entity(corporation) }
        end

        def player_distance_for_president(previous, entity)
          return 0 if !previous || !entity

          possible_players = if previous.player?
                               @players.rotate(@players.index(previous)).reject(&:bankrupt)
                             else
                               @players.reject(&:bankrupt)
                             end
          possible_corps = @corporations.reject(&:closed?).sort
          possible = [previous] + (possible_players + possible_corps).reject { |candidate| candidate == previous }

          a = possible.find_index(previous)
          b = possible.find_index(entity)
          return 0 if !a || !b

          a < b ? b - a : b - (a - possible.size)
        end

        def operating_round(round_num)
          G1872::Round::Operating.new(self, [
            G1872::Step::Bankrupt,
            Engine::Step::Exchange,
            G1872::Step::SpecialTrack,
            Engine::Step::BuyCompany,
            Engine::Step::HomeToken,
            G1872::Step::SpecialToken,
            G1872::Step::TrackAndToken,
            G1872::Step::Route,
            Engine::Step::Dividend,
            Engine::Step::DiscardTrain,
            G1872::Step::BuyTrain,
            G1872::Step::CorporateAction,
            Engine::Step::DiscardTrain,
            [Engine::Step::BuyCompany, { blocks: true }],
          ], round_num: round_num)
        end

        def ew_bonus(stops)
          east = stops.find { |stop| stop.groups.include?('East') }
          west = stops.find { |stop| stop.groups.include?('West') }

          east && west ? self.class::EW_BONUS : 0
        end

        def revenue_for(route, stops)
          super + ew_bonus(stops)
        end

        def revenue_str(route)
          str = super
          str += ' + E/W' if ew_bonus(route.stops).positive?
          str
        end

        def can_run_route?(entity)
          return false if entity&.corporation? && isolated_shell?(entity)

          super
        end

        def pay_land_grant_subsidy_for_first_route!(corporation)
          land_grants = @land_grant_child.select { |grant, child| child == corporation && !grant.closed? }.keys
          return if land_grants.empty?

          land_grants.each do |land_grant|
            value = land_grant.value.to_i
            receiver = land_grant.owner
            @bank.spend(value, receiver) if value.positive?
            @log << "#{receiver.name} receives #{format_currency(value)} from #{land_grant.name}" if value.positive?
            land_grant.value = 0
            return_land_grant_bid_marker!(land_grant)
            land_grant.close!
            land_grant.owner.companies.delete(land_grant) if land_grant.owner.respond_to?(:companies)
            @land_grant_child.delete(land_grant)
            @log << "#{land_grant.name} closes"
          end
        end

        def check_other(route)
          super
          check_multiple_cities_in_same_hex(route)
          check_ew_endpoints(route)
        end

        def train_help(_entity, runnable_trains, _routes)
          return [] unless runnable_trains.any? { |train| train.name == '8+' }

          ['8+ trains may visit any number of towns; only cities and offboards count toward the 8.']
        end

        def check_multiple_cities_in_same_hex(route)
          multiple_cities = route.visited_stops
                                 .select(&:city?)
                                 .group_by(&:hex)
                                 .any? { |_hex, cities| cities.size > 1 }
          return unless multiple_cities

          raise GameError, 'Train cannot visit multiple cities in the same hex'
        end

        def game_end_check_mines_connection?
          if @mines_connection_needs_update
            connected_east_hex = colorado_mines_connected_east_hex
            if connected_east_hex && !@mines_connection_reached
              @log << "-- Event: Colorado Mines is connected to #{east_connection_name(connected_east_hex)} --"
            end

            @mines_connection_reached = !!connected_east_hex
            @mines_connection_needs_update = false
          end

          @mines_connection_reached
        end

        def mines_connection_changed!
          @mines_connection_needs_update = true
        end

        def colorado_mines_connected_to_east?
          !!colorado_mines_connected_east_hex
        end

        def colorado_mines_connected_east_hex
          target_hexes = self.class::EASTERN_CONNECTION_HEXES.map { |hex_id| hex_by_id(hex_id) }
          reached_hexes = {}

          hex_by_id(self.class::COLORADO_MINES_HEX).tile.offboards.each do |offboard|
            offboard.walk(corporation: nil, visited: {}, visited_paths: {}) do |path, _visited, _counter, _converging|
              reached_hexes[path.hex] = true
            end
          end

          target_hexes.find { |hex| reached_hexes[hex] }
        end

        def east_connection_name(hex)
          hex.location_name.split(' +').first
        end

        def check_ew_endpoints(route)
          east_count = route.visited_stops.count { |stop| stop.groups.include?('East') }
          west_count = route.visited_stops.count { |stop| stop.groups.include?('West') }

          raise GameError, 'Route cannot connect two East areas' if east_count > 1
          raise GameError, 'Route cannot connect two West areas' if west_count > 1
        end

        def check_connected(route, corporation)
          super(route, token_corporation(corporation))
        end

        def tile_lays(entity)
          lays = super
          return lays unless company_by_id('CMA')&.owner == entity

          [
            *lays,
            { lay: true, upgrade: true },
          ]
        end

        def must_buy_train?(entity)
          return false if entity&.corporation? && isolated_shell?(entity)

          super
        end

        def use_big_creek_land_company!(corporation, city: nil)
          company = company_by_id('BCLC')
          raise GameError, 'Big Creek Land Company is not available' unless company && !company.closed?
          raise GameError, "#{corporation.name} does not own Big Creek Land Company" unless company.owner == corporation

          hex = hex_by_id('H26')
          reserved_city = hex.tile.cities.first
          city ||= reserved_city
          raise GameError, 'Big Creek Land Company must be used in the Hays reservation' unless city == reserved_city
          raise GameError, "#{corporation.name} cannot place the Big Creek token on #{hex.name}" unless city
          raise GameError, "#{hex.name} already has a token" if city.tokened?

          token = Token.new(corporation, price: 0)
          corporation.tokens << token
          city.place_token(corporation, token, free: true, check_tokenable: false)
          city.remove_reservation!(company)
          @log << "#{corporation.name} places a new Big Creek station marker in #{hex.name}"
          company_closing_after_using_ability(company)
          company.close!
          assimilate_connected_shells!
        end

        def issuable_shares(entity)
          return [] if !entity.corporation? || !entity.share_price

          treasury_shares = entity.shares.select do |share|
            share.corporation == entity && share.owner == entity && !share.president && share.buyable
          end

          (1..treasury_shares.size)
            .map { |number| ShareBundle.new(treasury_shares.take(number)) }
            .select { |bundle| @share_pool.fit_in_bank?(bundle) }
            .each { |bundle| bundle.share_price = entity.share_price.price }
        end

        def acting_for_entity(entity)
          controller = entity&.owner
          seen = {}
          while controller&.corporation?
            return nil if seen[controller]

            seen[controller] = true
            controller = controller.owner
          end
          controller
        end

        def purchasable_companies(entity = nil)
          buyer = entity || current_entity
          return [] if @round&.operating? && buyer&.corporation? && isolated_shell?(buyer)

          sellers = if buyer&.corporation?
                      [acting_for_entity(buyer), *genealogy_company_purchase_sellers(buyer)]
                    else
                      [buyer]
                    end
          sellers.compact!
          return [] unless sellers.any? { |seller| seller.player? || seller.corporation? }

          @companies.select do |company|
            sellers.include?(company.owner) && !abilities(company, :no_buy)
          end
        end

        def genealogy_company_purchase_sellers(buyer)
          return [] unless genealogy_company_purchases_variant?

          @corporations.select do |corporation|
            corporation != buyer && corporation.owner && !corporation.closed? && same_genealogy?(buyer, corporation)
          end
        end

        def company_sellable(company)
          return true if @round&.operating? &&
            current_entity&.corporation? &&
            purchasable_companies(current_entity).include?(company)

          super
        end

        def chain_of_control(entity)
          chain = []
          owner = entity&.owner
          while owner
            return chain << nil if chain.include?(owner)

            chain << owner
            owner = owner.owner if owner.corporation?
            break unless owner&.corporation?
          end
          chain << owner if owner && chain.last != owner
          chain
        end

        def chain_of_corps(entity)
          [entity] + chain_of_control(entity).select(&:corporation?)
        end

        def emr_bundles_for(corporation)
          bundles = @corporations.flat_map do |issued_corporation|
            next [] if corporation.shares_of(issued_corporation).empty?

            all_bundles_for_corporation(corporation, issued_corporation)
          end
          bundles.reject!(&:presidents_share)
          bundles.select! { |bundle| @share_pool.fit_in_bank?(bundle) }
          bundles.each { |bundle| bundle.share_price = bundle.corporation.share_price.price / 2.0 }
          investments, own_issues = bundles.partition { |bundle| bundle.corporation != corporation }
          investments.empty? ? own_issues : investments
        end

        def emergency_issuable_bundles(corporation, needed = nil)
          remaining = needed || @depot.min_depot_price
          chain_of_corps(corporation).each do |owner|
            remaining -= owner.cash
            return [] unless remaining.positive?

            bundles = emr_bundles_for(owner)
            next if bundles.empty?

            bundles.select! do |bundle|
              bundle.num_shares <= (remaining.to_f / bundle.price_per_share).ceil
            end
            return bundles
          end
          []
        end

        def emergency_cash_before_issuing(corporation, needed = nil)
          remaining = needed || @depot.min_depot_price
          total = 0
          chain_of_corps(corporation).each do |owner|
            total += owner.cash
            remaining -= owner.cash
            return total if !remaining.positive? || !emr_bundles_for(owner).empty?
          end
          total
        end

        def emergency_issuable_cash(corporation)
          chain_of_corps(corporation).sum do |owner|
            owner.cash + (emr_bundles_for(owner).max_by(&:price)&.price || 0)
          end - emergency_cash_before_issuing(corporation)
        end

        def emergency_player_sellable_bundles(player, active_corporation, corporation = nil, allow_unoperated: false)
          corporations = corporation ? [corporation] : @corporations
          corporations.flat_map do |share_corporation|
            next [] if !allow_unoperated && !corporation_share_sellable?(share_corporation)
            next [] if player.shares_of(share_corporation).empty?
            next [] unless share_corporation.share_price

            bundles = all_bundles_for_corporation(player, share_corporation)
            bundles.each { |bundle| bundle.share_price = share_corporation.share_price.price / 2.0 }
            bundles.select do |bundle|
              emergency_player_can_sell?(player, bundle, active_corporation, allow_unoperated: allow_unoperated)
            end
          end
        end

        def emergency_player_can_sell?(player, bundle, active_corporation, allow_unoperated: false)
          return false unless bundle.owner == player
          return false if !allow_unoperated && !corporation_share_sellable?(bundle.corporation)
          return false unless bundle.corporation.share_price
          return false unless @share_pool.fit_in_bank?(bundle)
          return false if sponsored_corporation?(bundle.corporation) && bundle.presidents_share
          return false if bundle.corporation == active_corporation && causes_presidency_change?(player, bundle)
          return false if active_corporation&.type == :shell &&
                          corporation_ancestor?(active_corporation, bundle.corporation) &&
                          causes_presidency_change?(player, bundle)

          return true unless bundle.presidents_share

          bundle.can_dump?(player)
        end

        def causes_presidency_change?(player, bundle)
          corporation = bundle.corporation
          return false unless corporation.president?(player)

          share_holders = corporation.player_share_holders(corporate: true)
          remaining = share_holders[player] - bundle.percent
          next_highest = share_holders.reject { |holder, _percent| holder == player }.values.max || 0
          remaining < next_highest
        end

        def emergency_player_sellable_cash(player, active_corporation, allow_unoperated: false)
          player.shares_by_corporation.sum do |corporation, shares|
            next 0 if shares.empty?

            emergency_player_sellable_bundles(
              player,
              active_corporation,
              corporation,
              allow_unoperated: allow_unoperated,
            ).max_by(&:price)&.price || 0
          end
        end

        def sellable_bundles(player, corporation)
          step = @round&.active_step
          return step.sellable_bundles(player, corporation) if step.is_a?(G1872::Step::BuyTrain) && player&.player?

          super
        end

        def check_sale_timing(entity, bundle)
          corporation_share_sellable?(bundle.corporation) && super
        end

        def corporation_share_sellable?(corporation)
          corporation&.share_price && corporation&.operated?
        end

        def liquidity(player, emergency: false)
          return super unless emergency

          active_corporation = @round&.current_entity
          player.cash + emergency_player_sellable_cash(player, active_corporation, allow_unoperated: true)
        end

        def total_emr_buying_power(player, corporation)
          emergency_cash_before_issuing(corporation) +
            emergency_issuable_cash(corporation) +
            player.cash +
            emergency_player_sellable_cash(player, corporation, allow_unoperated: true)
        end

        def sponsored_corporation?(corporation)
          corporation.presidents_share.owner&.corporation?
        end

        def hostile_takeover_variant?
          optional_rules&.include?(:hostile_takeover_variant)
        end

        def genealogy_company_purchases_variant?
          optional_rules&.include?(:genealogy_company_purchases)
        end

        def float_corporation(corporation)
          super
          return if corporation.type == :shell

          issue_parent_float_shares(corporation)
          purchase_starting_tokens(corporation)
        end

        def issue_parent_float_shares(corporation)
          shares = corporation.shares.select do |share|
            share.owner == corporation && !share.president && share.buyable
          end.first(5)
          raise GameError, "#{corporation.name} does not have five shares to issue on float" if shares.size < 5

          bundle = ShareBundle.new(shares)
          @share_pool.sell_shares(bundle, allow_president_change: false)
        end

        def purchase_starting_tokens(corporation, count = 1, home_city: nil)
          raise GameError, 'A corporation must buy one station marker' unless count == 1

          cost = count * self.class::TOKEN_PRICE
          raise GameError, "#{corporation.name} cannot afford #{format_currency(cost)} for station markers" if
            corporation.cash < cost

          if home_city
            raise GameError, "#{corporation.name}'s home station is no longer on the map" unless
              corporation.tokens.any? { |token| token.used && token.city == home_city }
          elsif corporation.tokens.first&.used
            count.times { corporation.tokens << Token.new(corporation, price: 0) }
          else
            corporation.tokens.clear
            (count + 1).times { corporation.tokens << Token.new(corporation, price: 0) }
          end
          corporation.spend(cost, @bank)

          place_home_token(corporation) unless home_city

          message = if home_city
                      "#{corporation.name} pays #{format_currency(cost)} for its home station marker"
                    else
                      "#{corporation.name} buys one additional token for #{format_currency(cost)}"
                    end
          @log << message
        end

        def all_potential_upgrades(tile, tile_manifest: false, selected_company: nil)
          upgrades = super
          return upgrades if tile_manifest

          upgrades.reject { |upgrade| upgrade.name == '8' }
        end

        def upgrades_to?(from, to, special = false, selected_company: nil)
          return true if from.name == '9' && %w[141 142].include?(to.name)
          return true if from.name == '141' && %w[141a 141b].include?(to.name)
          return true if from.name == '141a' && to.name == '141aG'
          return true if from.name == '142' && %w[142a 142b].include?(to.name)
          return true if from.name == '57' && %w[441 442].include?(to.name)
          return true if from.name == '205' && to.name == '441'
          return true if from.name == '206' && to.name == '442'
          return false if %w[141 142].include?(to.name)
          return false if %w[441 442].include?(to.name)

          super
        end
      end
    end
  end
end
