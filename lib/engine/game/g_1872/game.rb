# frozen_string_literal: true

require_relative '../base'
require_relative 'city'
require_relative 'corporation'
require_relative 'entities'
require_relative 'map'
require_relative 'meta'
require_relative 'round/auction'
require_relative 'round/operating'
require_relative 'step/bankrupt'
require_relative 'step/buy_sell_par_shares'
require_relative 'step/buy_train'
require_relative 'step/buy_tokens'
require_relative 'step/corporation_action'
require_relative 'step/land_grant_auction'
require_relative 'step/special_token'
require_relative 'step/special_track'
require_relative 'step/token'
require_relative 'step/track'
require_relative 'step/track_and_token'

module Engine
  module Game
    module G1872
      class Game < Game::Base
        CORPORATION_CLASS = G1872::Corporation

        include_meta(G1872::Meta)
        include Entities
        include Map

        BANK_CASH = 12_000
        CAPITALIZATION = :incremental
        FLOAT_PERCENT = 50
        SELL_BUY_ORDER = :sell_buy
        MUST_EMERGENCY_ISSUE_BEFORE_EBUY = true
        BANKRUPTCY_ENDS_GAME_AFTER = :all_but_one
        GAME_END_CHECK = { bankrupt: :immediate, bank: :full_or, stock_market: :immediate }.freeze
        TOKEN_PRICE = 100

        TILE_COST = 20
        EW_BONUS = 100
        LAND_GRANT_ROW_COUNT = 4
        LAND_GRANT_ROW_SIZE = 7
        LAND_GRANT_HEXES = %w[
          B20 B28 B4 C11 C27 C29 D24 D34 D4 E13 E21 E33 F24 F32 G13 G17 H32 H34 H38 H4 I13 I19 J28
          J30 J36 J6 K19 K9
        ].freeze

        # Two track actions. Both may be upgrades, including on the same hex.
        TILE_LAYS = [{ lay: true, upgrade: true }, { lay: true, upgrade: true }].freeze

        CERT_LIMIT = { 2 => 28, 3 => 20, 4 => 16, 5 => 13, 6 => 11 }.freeze

        STARTING_CASH = { 2 => 1200, 3 => 800, 4 => 600, 5 => 480, 6 => 400 }.freeze

        MARKET = [
          %w[74 82 90 100 111 122 135 149 165 182 200 222 246 272 300p 332 368 408 452 500e],
          %w[67 74 82 90 100 111 122 135 149 165 182 200p 222 246 272 300 332 368],
          %w[60 67 74 82 90 100 111 122 135p 149 165 182 200 222 246 272],
          %w[53 60 67 74 82 90p 100 111 122 135 149 165 182 200],
          %w[46 53 60p 67 74 82 90 100 111 122 135 149],
          %w[39 46 53 60 67 74 82 90 100 111 122],
          %w[33 39 46 53 60 67 74 82 90 100],
          %w[27 33 39 46 53 60 67 74 82],
          %w[21 27 33 39 46 53 60 67],
          %w[15 21 27 33 39 46 53],
          %w[9 15 21 27 33 39],
          %w[3 9 15 21 27],
        ].freeze

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
            on: '8',
            train_limit: 2,
            tiles: %i[yellow green brown gray],
            operating_rounds: 3,
          },
          {
            name: 'D',
            on: 'D',
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
          { name: '6', distance: 6, price: 630, num: 2 },
          { name: '7', distance: 7, price: 840, num: 1 },
          { name: 'D', distance: 999, price: 1080, num: 99 },
        ].freeze

        def stock_round
          Engine::Round::Stock.new(self, [
            Engine::Step::DiscardTrain,
            Engine::Step::Exchange,
            G1872::Step::SpecialTrack,
            G1872::Step::BuySellParShares,
          ])
        end

        attr_reader :land_grants, :pending_token_buys, :shell_parent, :shell_path, :shell_root, :isolated_shell_homes

        def setup_preround
          @land_grants = build_land_grants
          @companies.concat(@land_grants)
          @ipo_rows = @land_grants.sort_by { rand }.each_slice(self.class::LAND_GRANT_ROW_SIZE).to_a
        end

        def setup
          @pending_token_buys = []
          @shell_parent = {}
          @shell_path = {}
          @shell_root = {}
          @shell_child_count = Hash.new(0)
          @isolated_shell_homes = {}
        end

        def init_round
          new_land_grant_auction_round
        end

        def next_round!
          @round =
            case @round
            when G1872::Round::Auction
              clear_programmed_actions
              @players.each(&:unpass!)
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
                new_land_grant_auction_round
              end
            end
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

        def ipo_row_title(_ipo_row_number)
          nil
        end

        def ipo_row_companies_title
          'Grants'
        end

        def ipo_rows
          @ipo_rows || []
        end

        def buyable_bank_owned_companies
          return [] if @round.is_a?(G1872::Round::Auction)

          super.reject { |company| company.type == :land_grant }
        end

        def show_value_of_companies?(entity)
          return true if entity == @bank && @round.is_a?(G1872::Round::Auction)

          super
        end

        def company_header(company)
          return 'LAND GRANT' if company.type == :land_grant

          super
        end

        def remove_land_grant(company)
          @ipo_rows.each { |row| row.delete(company) }
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
          self.class::LAND_GRANT_HEXES.map do |hex_id|
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
          return true if owner == corporation
          return false if corporation_ancestor?(owner, corporation)
          return direct_child?(owner, corporation) if corporation_ancestor?(corporation, owner)

          true
        end

        def token_corporation(corporation)
          return corporation unless corporation&.type == :shell
          return corporation if isolated_shell?(corporation)

          @shell_root[corporation] || corporation
        end

        def isolated_shell?(corporation)
          @isolated_shell_homes.key?(corporation)
        end

        def land_grant_hex_id(land_grant)
          land_grant.sym.delete_prefix('LG-')
        end

        def player_land_grants(player)
          @land_grants.select { |company| company.owner == player && !company.closed? }
        end

        def usable_land_grant?(land_grant, corporation)
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
          shell.companies << land_grant unless shell.companies.include?(land_grant)
          land_grant.owner.companies.delete(land_grant) if land_grant.owner&.respond_to?(:companies)
          land_grant.owner = shell
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
          return true unless token&.city
          return false unless parent

          token_graph_for_entity(token_corporation(parent)).connected_nodes(token_corporation(parent)).key?(token.city)
        end

        def assimilate_shell_home!(shell, parent = @shell_parent[shell])
          token = @isolated_shell_homes.delete(shell) || shell.tokens.find(&:used)
          return unless token

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
          super(city, entity) || (entity&.type == :shell && super(city, token_corporation(entity)))
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
            step = @round&.steps&.find { |candidate| candidate.is_a?(G1872::Step::CorporationAction) }
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

        def corporations
          @corporations
        end

        def all_corporations
          corporations
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
            Engine::Step::Route,
            Engine::Step::Dividend,
            Engine::Step::DiscardTrain,
            G1872::Step::BuyTrain,
            G1872::Step::CorporationAction,
            Engine::Step::DiscardTrain,
            [Engine::Step::BuyCompany, { blocks: true }],
          ], round_num: round_num)
        end

        def upgrade_cost(tile, hex, entity, spender)
          [self.class::TILE_COST, super].max
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
          return false if isolated_shell?(entity)

          super
        end

        def check_other(route)
          super
          check_ew_endpoints(route)
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
          return [] if buyer&.corporation? && buyer.type == :shell

          controller = buyer&.corporation? ? acting_for_entity(buyer) : buyer
          return [] unless controller&.player?

          @companies.select do |company|
            company.owner == controller && !abilities(company, :no_buy)
          end
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

        def emergency_player_sellable_bundles(player, active_corporation, corporation = nil)
          corporations = corporation ? [corporation] : @corporations
          corporations.flat_map do |share_corporation|
            next [] if player.shares_of(share_corporation).empty?
            next [] unless share_corporation.share_price

            bundles = all_bundles_for_corporation(player, share_corporation)
            bundles.each { |bundle| bundle.share_price = share_corporation.share_price.price / 2.0 }
            bundles.select { |bundle| emergency_player_can_sell?(player, bundle, active_corporation) }
          end
        end

        def emergency_player_can_sell?(player, bundle, active_corporation)
          return false unless bundle.owner == player
          return false unless bundle.corporation.share_price
          return false unless @share_pool.fit_in_bank?(bundle)
          return false if sponsored_corporation?(bundle.corporation) && bundle.presidents_share
          return false if bundle.corporation == active_corporation && causes_presidency_change?(player, bundle)

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

        def emergency_player_sellable_cash(player, active_corporation)
          player.shares_by_corporation.sum do |corporation, shares|
            next 0 if shares.empty?

            emergency_player_sellable_bundles(player, active_corporation, corporation).max_by(&:price)&.price || 0
          end
        end

        def sellable_bundles(player, corporation)
          step = @round&.active_step
          if step.is_a?(G1872::Step::BuyTrain) && player&.player?
            return step.sellable_bundles(player, corporation)
          end

          super
        end

        def liquidity(player, emergency: false)
          return super unless emergency

          active_corporation = @round&.current_entity
          player.cash + emergency_player_sellable_cash(player, active_corporation)
        end

        def total_emr_buying_power(player, corporation)
          emergency_cash_before_issuing(corporation) +
            emergency_issuable_cash(corporation) +
            player.cash +
            emergency_player_sellable_cash(player, corporation)
        end

        def sponsored_corporation?(corporation)
          corporation.presidents_share.owner&.corporation?
        end

        def hostile_takeover_variant?
          optional_rules&.include?(:hostile_takeover_variant)
        end

        def float_corporation(corporation)
          super
          return if corporation.type == :shell

          purchase_starting_tokens(corporation)
        end

        def purchase_starting_tokens(corporation, count = 1, home_city: nil)
          raise GameError, 'A corporation must buy one station marker' unless count == 1

          cost = count * self.class::TOKEN_PRICE
          raise GameError, "#{corporation.name} cannot afford #{format_currency(cost)} for station markers" if
            corporation.cash < cost

          if home_city
            raise GameError, "#{corporation.name}'s home station is no longer on the map" unless
              corporation.tokens.any? { |token| token.used && token.city == home_city }
          else
            corporation.tokens.clear
            (count + 1).times { corporation.tokens << Token.new(corporation, price: 0) }
          end
          corporation.spend(cost, @bank)

          place_home_token(corporation) unless home_city

          if home_city
            @log << "#{corporation.name} pays #{format_currency(cost)} for its home station marker"
          else
            @log << "#{corporation.name} buys one additional token for #{format_currency(cost)}"
          end
        end

        def upgrades_to?(from, to, special = false, selected_company: nil)
          return true if from.name == '9' && %w[141 142].include?(to.name)
          return true if from.name == '141' && %w[141a 141b].include?(to.name)
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
