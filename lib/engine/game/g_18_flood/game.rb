# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'
require_relative 'corporations'
require_relative 'map'
require_relative 'tiles'
require_relative 'trains'
require_relative 'market'
require_relative 'phases'
require_relative 'share_pool'

module Engine
  module Game
    module G18FLOOD
      class Game < Game::Base
        include_meta(G18FLOOD::Meta)
        include Corporations
        include Map
        include Tiles
        include Trains
        include Market
        include Phases

        TRACK_RESTRICTION = :permissive
        SELL_BUY_ORDER = :sell_buy
        TILE_RESERVATION_BLOCKS_OTHERS = :always
        CURRENCY_FORMAT_STR = '$%s'
        BANK_CASH = 99_999
        CAPITALIZATION = :incremental
        CERT_LIMIT = { 3 => 99 }.freeze
        STARTING_CASH = { 3 => 1_200 }.freeze

        EVENTS_TEXT = Base::EVENTS_TEXT.merge.freeze
        STATUS_TEXT = Base::STATUS_TEXT.merge.freeze

        CERT_LIMIT_INCLUDES_PRIVATES = false
        MIN_BID_INCREMENT = 5
        MUST_BID_INCREMENT_MULTIPLE = true
        ONLY_HIGHEST_BID_COMMITTED = true
        MARKET_SHARE_LIMIT = 100
        SOLD_OUT_INCREASE = false
        POOL_SHARE_DROP = :none
        SELL_MOVEMENT = :left_block
        HOME_TOKEN_TIMING = :float
        MUST_BUY_TRAIN = :never
        DISCARDED_TRAINS = :remove
        CLOSED_CORP_TRAINS_REMOVED = true

        # GAME_END_CHECK = { custom: :immediate }.freeze
        # GAME_END_REASONS_TEXT = Base::GAME_END_REASONS_TEXT.merge(
        #   custom: 'Fixed number of Rounds'
        # )

        NATIONAL_STARTING_PRICE = 120

        PROGRESS_INFORMATION = [
          { type: :SR, name: '1' },
          { type: :OR, name: '1.1' },
          { type: :OR, name: '1.2' },
          { type: :OR, name: '1.3' },
          { type: :SR, name: '2' },
          { type: :OR, name: '2.1' },
          { type: :OR, name: '2.2' },
          { type: :SR, name: '3' },
          { type: :OR, name: '3.1' },
          { type: :OR, name: '3.2' },
          { type: :SR, name: '4' },
          { type: :OR, name: '4.1' },
          { type: :OR, name: '4.2' },
          { type: :SR, name: '5' },
          { type: :OR, name: '5.1' },
          { type: :OR, name: '5.2' },
          { type: :SR, name: '6' },
          { type: :OR, name: '6.1' },
          { type: :SR, name: '7' },
          { type: :OR, name: '7.1' },
          { type: :SR, name: '8' },
          { type: :OR, name: '8.1' },
          { type: :End },
        ].freeze

        CENTER_PLAN = [
          { to: 'FLDS2', need: 100 },  # yellow -> green
          { to: 'FLDS3', need: 200 },  # green  -> brown
          { to: 'FLDS4', need: 300 },  # brown  -> gray
          { to: 'FLDS5', need: 400 },  # gray   -> purple
        ].freeze

        CENTER_PHASE_CONTRIBUTION = {
          'A' => 50, 'B' => 40, 'C' => 30, 'D' => 20, 'E' => 10, 'F' => 5
        }.freeze

        GREEN_CITY_SEEDS_BY_RING = { 2 => 6, 3 => 4, 4 => 3, 5 => 3 }.freeze
        BROWN_CITY_SEEDS_BY_RING = { 6 => 9 }.freeze
        GENERATED_CITY_TILES = %w[FLD21 FLD22 FLD31].freeze
        COASTAL_TRACK_EDGES = { '7' => [0, 1], '8' => [0, 2], '9' => [0, 3] }.freeze
        CORRIDOR_SWITCHBACK_BY_RING = { 5 => 0, 4 => 1, 3 => 0, 2 => -1 }.freeze
        GREEN_CITY_EDGES = {
          'FLD21' => [0, 1, 2, 4],
          'FLD22' => [0, 1, 3, 5],
        }.freeze
        TERRAIN_COST_FRACTIONS = {
          yellow: 2.0 / 3.0,
          green: 1.0 / 3.0,
          brown: 1.0 / 6.0,
          gray: 0.0,
        }.freeze
        TERRAIN_BASE_COST_BY_RING = {
          1 => 240, 2 => 240,
          3 => 120, 4 => 120,
          5 => 60, 6 => 60,
        }.freeze

        attr_accessor :steel, :lumber, :pending_shell, :center_fund, :center_stage,
                      :center_used
        attr_reader :city_corridor_sextants, :city_corridor_hexes

        def init_share_pool
          @share_pool = Engine::Game::G18FLOOD::SharePool.new(
            self,
            allow_president_sale: @allow_president_sale,
            no_rebundle_president_buy: @no_rebundle_president_buy
          )
        end

        def president_label_for(_corp) = 'controller'

        def progress_information
          self.class::PROGRESS_INFORMATION
        end

        def show_progress_bar?
          true
        end

        def show_game_cert_limit?
          false
        end

        def sell_movement(corporation = nil)
          return :none if national_corporation?(corporation)

          self.class::SELL_MOVEMENT
        end

        def nationals
          corporations.select { |c| c.type == :national }.sort_by(&:name)
        end

        def national_corporation?(entity)
          entity&.corporation? && entity.type == :national
        end

        def shells
          corporations.select { |c| c.type == :shell }.sort_by(&:name)
        end

        def shell_corporation?(entity)
          entity&.corporation? && entity.type == :shell
        end

        def shell_first_or?(entity)
          shell_corporation?(entity) && !entity.operated? && entity.floated?
        end

        def player_value(player)
          total = 0
          total += player.cash
          total += player.companies.sum(&:value) if player.respond_to?(:companies)

          @corporations.each do |corp|
            percent = player.percent_of(corp)
            next if percent.zero?

            ten_pct_shares = percent / 10

            if national_corporation?(corp)
              per_share_cash = corp.total_shares.positive? ? (corp.cash / corp.total_shares) : 0
              total += ten_pct_shares * per_share_cash
            else
              price = corp.share_price&.price || 0
              total += ten_pct_shares * price
            end
          end

          total
        end

        def center_hex_id = self.class::CENTER_CITY.first
        def center_hex?(hex_or_id) = (hex_or_id.respond_to?(:id) ? hex_or_id.id : hex_or_id) == center_hex_id

        def center_phase_contribution
          CENTER_PHASE_CONTRIBUTION.fetch(@phase.name, 5)
        end

        def compute_center_stage!
          sequence = %w[FLDS1 FLDS2 FLDS3 FLDS4 FLDS5]
          current  = hex_by_id(center_hex_id)&.tile&.name
          idx      = sequence.index(current) || 0
          @center_stage = [idx, CENTER_PLAN.size].min
        end

        def center_next_need
          step = CENTER_PLAN[@center_stage]
          step && step[:need]
        end

        def center_remaining_to_next
          need = center_next_need
          return nil unless need

          rem = need - (@center_fund || 0)
          rem.positive? ? rem : 0
        end

        def center_contribute!(amount)
          amt = amount.to_i
          return if amt <= 0

          need_before = center_next_need
          @center_fund += amt

          return unless need_before

          delta = @center_fund - need_before

          @log << if delta.negative?
                    "Public Works gains #{format_currency(amt)} toward city-center improvements "\
                      "(#{format_currency(-delta)} more to next upgrade)"
                  elsif delta.zero?
                    "Public Works gains #{format_currency(amt)} toward city-center improvements"
                  else
                    "Public Works gains #{format_currency(amt)} toward city-center improvements "\
                      "(#{format_currency(delta)} remaining in fund)"
                  end
        end

        def maybe_auto_upgrade_center!
          loop do
            step = CENTER_PLAN[@center_stage]
            break unless step
            break if @center_fund < step[:need]

            hex = hex_by_id(center_hex_id) or break
            target = step[:to]
            break if hex.tile&.name == target

            old = hex.tile
            new_tile = pool_tile(target)
            new_tile.rotate!(old.rotation)
            update_tile_lists(new_tile, old)
            hex.lay(new_tile)

            @center_fund  -= step[:need]
            @center_stage += 1
            @log << 'Public Works upgrades the city center'
          end
        end

        def or_set_finished
          super
          flood_event! if symmetrical_map?
        end

        def or_round_finished
          super
          advance_flood_clock!
        end

        def advance_flood_clock!
          @completed_operating_rounds = (@completed_operating_rounds || 0) + 1
          flood_event! if !symmetrical_map? && @completed_operating_rounds.even?
        end

        def compute_flood_rings!
          center_id  = self.class::CENTER_CITY.first
          center_hex = hex_by_id(center_id)

          @flood_rings = {}
          @max_flood_ring = 0
          return unless center_hex

          rings = Hash.new { |hash, key| hash[key] = [] }
          @hexes.each do |hex|
            next if outer_water_ring.include?(hex.id)

            ring = geometric_ring(hex, center_hex)
            rings[ring] << hex.id
          end
          rings.each_value(&:sort!)

          @flood_rings    = rings
          @max_flood_ring = rings.keys.max || 0
        end

        def geometric_ring(hex, center = hex_by_id(center_hex_id))
          dx = hex.x - center.x
          dr = ((hex.y - center.y) - dx) / 2
          [dx.abs, dr.abs, (dx + dr).abs].max
        end

        def ring_for_flood_index(idx)
          compute_flood_rings! unless @flood_rings
          @flood_rings[idx] || []
        end

        def flood_event!
          compute_flood_rings! unless @flood_rings
          idx  = (@flood_ring_index || @max_flood_ring)
          ring = @flood_rings[idx] || []
          return if ring.empty?

          ring.each do |hid|
            hex = hex_by_id(hid)
            next unless hex

            old_tile = hex.tile
            next unless old_tile
            next if old_tile.name == 'FLOOD'

            # remove any tokens on cities
            old_tile.cities.each do |city|
              city.tokens.compact.each do |token|
                corp = token.corporation
                token.remove!
                corp.tokens.delete(token)
                if corp.coordinates
                  coords = Array(corp.coordinates)
                  corp.coordinates = nil if coords.include?(hex.id)
                end
              end
            end

            # clear cached hex label so location names disappear post-flood
            if hex.respond_to?(:location_name=)
              hex.location_name = nil
            elsif hex.instance_variable_defined?(:@location_name)
              hex.instance_variable_set(:@location_name, nil)
            end

            # Use a managed pool tile so tile inventory and replay state remain consistent.
            lay_from_pool!(hid, 'FLOOD', 0)
          end

          # close corps that don't have any tokens on the map
          closing = (@corporations || []).select { |c| c.floated? && c.tokens.none?(&:used) }

          shells_of = lambda do |nat|
            if respond_to?(:shell_parent) && shell_parent
              shell_parent.select { |_sh, parent| parent == nat }.keys
            else
              (@corporations || []).select { |c| c.type == :shell && c.owner == nat }
            end
          end

          parent_of = {}
          closing.select { |c| national_corporation?(c) }.each do |nat|
            shells_of.call(nat).each { |sh| parent_of[sh] = nat }
          end

          (closing + parent_of.keys).uniq.each do |corp|
            @log << if parent_of[corp]
                      "#{corp.name} closes because its parent #{parent_of[corp].name} was closed by the flood"
                    else
                      "#{corp.name} loses its last station to the flood and closes"
                    end
            close_corporation(corp)
          end

          @flood_ring_index = idx - 1
          @log << '-- Event: Flood advances --'
          @graph&.clear_graph_for_all
        end

        def next_round!
          @round =
            case @round
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
                new_stock_round
              end
            when init_round.class
              init_round_finished
              new_operating_round
            end
        end

        def init_round_finished
          players_by_cash = @players.sort_by(&:cash).reverse
          player = players_by_cash[0]
          @log << "#{player.name} has the most cash and has priority deal"
          @players.rotate!(@players.index(player))
        end

        def rust?(_train, _trigger) = false
        def obsolete?(_train, _trigger) = false

        def degrade_for_current_phase
          {
            'A' => nil,
            'B' => '4A',
            'C' => '4B',
            'D' => '4C',
            'E' => '4D',
            'F' => '4E',
          }[@phase.name]
        end

        def new_auction_round
          @log << '-- Stock Round 1 --'
          G18FLOOD::Round::Auction.new(self, [
            G18FLOOD::Step::InitAuction,
          ])
        end

        def new_stock_round
          @sr += 1
          @round_counter += 1

          end_game! if @sr == 9

          if @sr <= 6
            @phase.next!
            @operating_rounds = @phase.operating_rounds
            if (tag = degrade_for_current_phase)
              depot.export_all!(tag)
            end
          end
          if @sr < 9
            degrade_trains!
            @log << "-- #{round_description('Stock')} --"
          end
          stock_round
        end

        def can_run_route?(entity)
          national_corporation?(entity) || super
        end

        def check_local_cities(routes)
          local_cities = []
          routes.each do |route|
            local_cities.concat(route.visited_stops.select(&:city?)) if route.train.local? && !route.chains.empty?
          end

          local_cities.group_by(&:itself).each do |k, v|
            raise GameError, "Local train can only use each token on #{k.hex.id} once" if v.size > 1
          end
        end

        # called by AutoRouter
        def check_other(route)
          check_local_cities(route.routes)
        end

        def upgrades_to?(from, to, special = false, selected_company: nil)
          return false if to.color == :purple

          super
        end

        def degrade_trains!
          @log << '-- Event: Train Degradation --'

          shells.each do |corp|
            to_rust = []

            corp.trains.each do |train|
              old_name = train.name
              number = train.name[0].to_i
              letter = train.name[1]

              if number == 1
                @log << "#{old_name} train is decommissioned (#{corp.full_name})"
                to_rust << train
              else
                train.distance -= 1
                train.name = "#{train.distance}#{letter}"
                train.instance_variable_set(:@local, true)
                @log << "#{old_name} train downgraded to a #{train.name} train (#{corp.full_name})"
              end
            end
            to_rust.each { |t| rust(t) }
          end
        end

        def new_operating_round(round_num = 1)
          @log << "-- #{round_description(self.class::OPERATING_ROUND_NAME, round_num)} --"
          @or += 1
          @round_counter += 1

          operating_round(round_num)
        end

        def stock_round
          G18FLOOD::Round::Stock.new(self, [
            G18FLOOD::Step::BuySellParShares,
          ])
        end

        def operating_round(round_num)
          G18FLOOD::Round::Operating.new(self, [
            Engine::Step::Exchange,
            Engine::Step::SpecialToken,
            G18FLOOD::Step::HomeToken,
            G18FLOOD::Step::ShellPostSwapShares,
            Engine::Step::DiscardTrain,
            G18FLOOD::Step::Track,
            G18FLOOD::Step::Token,
            G18FLOOD::Step::ResourceDelivery,
            G18FLOOD::Step::Route,
            G18FLOOD::Step::Dividend,
            G18FLOOD::Step::ShellChoice,
            G18FLOOD::Step::ParShell,
            G18FLOOD::Step::BuyTrain,
          ], round_num: round_num)
        end

        def par_prices(corp)
          if national_corporation?(corp)
            [stock_market.par_prices.find { |p| p.price == NATIONAL_STARTING_PRICE }]
          else
            stock_market.par_prices
          end
        end

        def home_token_locations(corporation)
          hexes.select do |hex|
            hex.tile.cities.any? { |c| c.tokenable?(corporation) }
          end
        end

        def tile_lays(_entity)
          [{ lay: true, upgrade: true, cost: 0, cannot_reuse_same_hex: false }] * 99
        end

        def status_array(corp)
          status = []
          return nil unless national_corporation?(corp)

          status << "Lumber: #{@lumber[corp]}"
          status << "Steel: #{@steel[corp]}"
          status
        end

        def init_round
          @round_counter += 1
          new_auction_round
        end

        def controller(entity)
          return entity if entity&.player?
          return nil    unless entity&.corporation?

          corp = shell_corporation?(entity) ? (shell_parent[entity] || entity) : entity

          owner = corp.owner
          seen  = {}
          while owner&.corporation? && !seen[owner]
            seen[owner] = true
            owner = owner.owner
          end

          return owner if owner&.player?
          return @share_pool if owner == @share_pool

          nil
        end

        def corporation_owner(entity)
          controller(entity)
        end

        def acting_for_entity(entity)
          return controller(shell_parent[entity] || entity) || entity if shell_corporation?(entity)

          entity&.player? ? entity : (controller(entity) || entity)
        end

        def chain_depth(entity)
          return 0 unless entity&.corporation?

          depth = 1
          owner = entity.owner
          while owner&.corporation?
            depth += 1
            owner = owner.owner
          end
          depth
        end

        def player_sort(entities)
          controller_order = []
          entities.each do |e|
            ctrl = acting_for_entity(e)
            controller_order << ctrl unless controller_order.include?(ctrl)
          end

          op_index = {}
          operating_order.each_with_index { |e, i| op_index[e] = i }

          grouped = entities.group_by { |e| acting_for_entity(e) }
          grouped.transform_values! do |arr|
            arr.sort_by do |e|
              [
                chain_depth(e),
                op_index[e] || Float::INFINITY,
                e.name,
              ]
            end
          end

          controller_order.to_h { |k| [k, grouped[k]] }
        end

        def train_help(entity, _runnable_trains, _routes)
          return [] unless national_corporation?(entity)

          ['Nationals run a hypothetical train of infinite length. '\
           'This train is allowed to run a route of just a single city.']
        end

        def setup
          super
          @or = 0
          @sr = 1
          @round_counter = 0
          @completed_operating_rounds = 0
          @lumber ||= Hash.new(0)
          @steel  ||= Hash.new(0)
          @flood_ring_index ||= @max_flood_ring
          @center_used = nil

          seed_map_tiles!
          @all_tiles.each { |tile| tile.hide if tile.name == 'FLOOD' }

          # allows all trains to run locally
          @depot.trains.each { |t| t.instance_variable_set(:@local, true) }

          nationals.each_with_index do |corp, i|
            train = train_by_id("INF-#{i}")
            @depot.remove_train(train)
            train.buyable = false
            train.owner = corp
            corp.trains << train

            @lumber[corp] = 5
            @steel[corp]  = 5
          end
          @center_fund ||= 0
          compute_center_stage!
        end

        # Hide labels for hexes that are flooded
        def location_name(hex_or_coord)
          hid = hex_or_coord.respond_to?(:id) ? hex_or_coord.id : hex_or_coord
          return nil if @suppressed_location_names && @suppressed_location_names[hid]

          super
        end

        def ipo_name(_entity = nil)
          'Treasury'
        end

        def ipo_verb(_entity = nil)
          'starts'
        end

        def tile_valid_for_phase?(tile, hex: nil, phase_color_cache: nil)
          tile.color != :purple
        end

        def timeline
          @timeline = [''].freeze
        end

        def check_distance(_route, visits)
          super
          raise GameError, 'Train cannot run to a lumber mill' if visits.any? { |node| lumber_mills.include?(node.hex.id) }
          raise GameError, 'Train cannot run to a steel mill' if visits.any? { |node| steel_mills.include?(node.hex.id) }
        end

        def lumber_mills
          @lumber_mills || self.class::LUMBER_MILLS
        end

        def steel_mills
          @steel_mills || self.class::STEEL_MILLS
        end

        def operating_order
          shell_order = shells.select(&:floated?).sort

          nat_by_player = @players.flat_map do |player|
            nationals.select { |n| controller(n) == player }
          end

          shell_order + nat_by_player
        end

        # --------------------------- Shell company helpers ---------------------------

        def begin_shell_post_swap_shares!(shell)
          starter_player = shell.owner.owner
          raise GameError, 'Shell has no owner player' unless starter_player&.player?

          @players.each(&:unpass!)

          @round.shell_ipo = {
            corp: shell,
            starter: starter_player,
            remaining: 30,
            phase: :starter,
            cursor: 0,
            acted: {},
          }
        end

        def shell_parent
          @shell_parent ||= {}
        end

        def available_shells
          @corporations.select { |c| c.type == :shell } - shell_parent.keys
        end

        def next_free_shell
          available_shells.find { |c| !c.floated? && c.share_price.nil? }
        end

        def ensure_free_token!(corp)
          tok = corp.tokens.find { |t| !t.used }
          return tok if tok

          t = Engine::Token.new(corp, price: 0)
          corp.tokens << t
          t
        end

        # --- Create/assign a pre-defined Shell -------------------------------------

        def create_shell_company(parent)
          shell = next_free_shell
          raise GameError, 'No unused Shell corporations remain' unless shell

          shell.ipoed       = false
          shell.floated     = false
          shell.share_price = nil

          ensure_free_token!(shell)

          shell_parent[shell] = parent

          # Put shell right after parent in the round order
          if @round.respond_to?(:entities)
            idx = @round.entities.index(parent)
            @round.entities.insert(idx + 1, shell) if idx && !@round.entities.include?(shell)
          end

          @pending_shell = { parent: parent, shell: shell }

          @graph.clear_graph_for_all
          @log << "#{parent.name} selects #{shell.full_name}"
          shell
        end

        def par_and_sell_president_to_parent(shell, parent, par_price)
          par_obj = @stock_market.par_prices.find { |pp| pp.price == par_price }
          raise GameError, 'Par price not available on the market' unless par_obj

          @stock_market.set_par(shell, par_obj)
          shell.full_name = "#{parent.full_name} – #{shell.full_name}"

          pres = shell.presidents_share
          raise GameError, 'Shell has no president share to buy' unless pres

          price = par_price * (pres.percent / 10)
          raise GameError, "#{parent.name} cannot afford #{format_currency(price)}" if parent.cash < price

          bundle = Engine::ShareBundle.new(pres, pres.percent)
          @share_pool.transfer_shares(bundle, parent, allow_president_change: true, price: price)

          parent.spend(price, shell)

          shell.ipoed = true
          shell.floated = true
          shell.owner   = parent

          shell_token_swap!(parent, shell)

          @pending_shell = nil
          @graph.clear_graph_for_all

          @log << "#{parent.name} sets par for #{shell.full_name} at #{format_currency(par_price)} "\
                  "and buys the 50% president’s share for #{format_currency(price)}"
        end

        def shell_swap_hexes(parent)
          @hexes.each_with_object([]) do |hex, arr|
            next unless hex.tile&.cities&.any?

            arr << hex if hex.tile.cities.any? { |c| c.tokens.any? { |t| t&.corporation == parent } }
          end
        end

        def shell_token_swap!(parent, shell)
          home_ids = Array(parent.coordinates).compact

          hexes = @hexes.select do |hex|
            next false if home_ids.include?(hex.id)

            hex.tile&.cities&.any? { |c| c.tokens.any? { |t| t&.corporation == parent } }
          end
          return if hexes.empty?

          token = shell.tokens.find { |t| !t.used } ||
                  begin
                    t = Engine::Token.new(shell, price: 0)
                    shell.tokens << t
                    t
                  end

          @round.pending_tokens << {
            entity: shell,
            token: token,
            parent: parent,
            hexes: hexes,
          }
        end

        # --- setup ------------------------------------------------

        def neighbor_ids(hid)
          (hex_by_id(hid)&.neighbors || {}).values.compact.map(&:id)
        end

        def blank_plain?(hex)
          t = hex&.tile
          t&.preprinted &&
            t.color == :white &&
            t.paths.empty? &&
            t.cities.empty? &&
            t.towns.empty? &&
            t.offboards.empty?
        end

        def isolated_blank_hex_id?(hid)
          hex = hex_by_id(hid)
          return false unless blank_plain?(hex)

          hex.neighbors.values.all? { |nbr| blank_plain?(nbr) }
        end

        def city_seed_hex?(hex)
          return false unless blank_plain?(hex)
          return false if hex.neighbors.values.compact.any? { |neighbor| self.class::HOME_HEXES.include?(neighbor.id) }

          mill_ids = Array(@lumber_mills) + Array(@steel_mills)
          return false if mill_ids.include?(hex.id)
          return false if hex.neighbors.values.compact.any? { |neighbor| mill_ids.include?(neighbor.id) }

          adjacent_cities = hex.neighbors.values.compact.select do |neighbor|
            GENERATED_CITY_TILES.include?(neighbor.tile.name)
          end
          return true if adjacent_cities.empty?
          return false unless adjacent_cities.one?

          neighbor = adjacent_cities.first
          neighbor.neighbors.values.compact.none? do |other|
            other != hex && GENERATED_CITY_TILES.include?(other.tile.name)
          end
        end

        def rings_from(center_hid)
          max_r = 9
          start = hex_by_id(center_hid) or raise GameError, "No hex #{center_hid}"
          rings = Hash.new { |h, k| h[k] = [] }
          dist  = { start.id => 0 }
          q = [start]
          until q.empty?
            h = q.shift
            d = dist[h.id]
            rings[d] << h.id if d <= max_r
            next if d == max_r

            h.neighbors.values.compact.each do |nh|
              next if dist.key?(nh.id)

              dist[nh.id] = d + 1
              q << nh
            end
          end
          rings
        end

        def sextant_index(center_hid, hid)
          col = hid[/\d+/].to_i
          row = hid[0].ord - 'A'.ord + 1
          ccol = center_hid[/\d+/].to_i
          crow = center_hid[0].ord - 'A'.ord + 1
          dx = col - ccol
          dy = row - crow
          ang = Math.atan2(dy, dx)
          ang += 2 * Math::PI if ang.negative?
          (ang / (Math::PI / 3)).floor % 6
        end

        def pool_tile(name)
          @tiles.find { |t| t.name == name && t.hex.nil? } or
            raise GameError, "No available tile named #{name}"
        end

        def lay_from_pool!(hex_id, name, rotation = r_mod(6))
          hex = hex_by_id(hex_id) or raise GameError, "Unknown hex #{hex_id}"
          old = hex.tile
          new_tile = pool_tile(name)
          new_tile.rotate!(rotation)
          update_tile_lists(new_tile, old)
          hex.lay(new_tile)
          new_tile
        end

        def ensure_mountain_upgrade_cost!(tile, cost)
          tile.upgrades.reject! { |u| Array(u.terrains) == [:mountain] }
          tile.upgrades << Engine::Part::Upgrade.new(cost, [:mountain], nil)
        end

        def base_terrain_cost(hex)
          original = hex.original_tile
          return 0 unless original

          cost = original.upgrades.sum { |upgrade| Integer(upgrade.cost || 0) }
          return cost unless original.preprinted && original.cities.any?

          case original.color
          when :yellow then (cost * 3.0 / 2).round
          when :green then cost * 3
          else cost
          end
        end

        def terrain_cost_for(hex, color)
          (base_terrain_cost(hex) * TERRAIN_COST_FRACTIONS.fetch(color, 0.0)).round
        end

        def seed_hex_for(rings, ring, sextant)
          rings[ring]
            .select { |hid| sextant_index(center_hex_id, hid) == sextant }
            .select { |hid| city_seed_hex?(hex_by_id(hid)) }
            .min_by { r_hi }
        end

        def symmetrical_map?
          @optional_rules&.include?(:symmetrical_map)
        end

        def rotated_hex_id(hex_id, edge_offset = 2)
          @rotated_hex_ids ||= {}
          return @rotated_hex_ids[[edge_offset, hex_id]] if @rotated_hex_ids.key?([edge_offset, hex_id])

          center = hex_by_id(center_hex_id)
          mapping = { center.id => center.id }
          queue = [center]
          until queue.empty?
            source = queue.shift
            rotated = hex_by_id(mapping[source.id])
            source.neighbors.each do |edge, neighbor|
              next unless neighbor

              rotated_neighbor = rotated.neighbors[(edge + edge_offset) % 6]
              next unless rotated_neighbor
              next if mapping.key?(neighbor.id)

              mapping[neighbor.id] = rotated_neighbor.id
              queue << neighbor
            end
          end
          mapping.each { |source_id, target_id| @rotated_hex_ids[[edge_offset, source_id]] = target_id }
          @rotated_hex_ids[[edge_offset, hex_id]]
        end

        def threefold_orbit(hex_id)
          second = rotated_hex_id(hex_id)
          third = rotated_hex_id(second)
          [hex_id, second, third].compact.uniq
        end

        def adjacent_to_city?(hex)
          hex.neighbors.values.compact.any? { |neighbor| neighbor.tile.cities.any? }
        end

        def relocate_mills!
          sources = (self.class::LUMBER_MILLS + self.class::STEEL_MILLS).map { |id| hex_by_id(id) }
          candidates = @hexes.select do |hex|
            blank_plain?(hex) && !adjacent_to_city?(hex) && !sources.include?(hex)
          end
          candidates.sort_by! { r_hi }
          destinations = nonadjacent_hexes(candidates, sources.size)
          raise GameError, 'Unable to place resource mills without clustering' unless destinations

          sources.zip(destinations).each do |source, destination|
            source_tile = source.tile
            destination_tile = destination.tile
            source.tile = destination_tile
            destination.tile = source_tile
            cost = TERRAIN_BASE_COST_BY_RING[geometric_ring(source)]
            ensure_mountain_upgrade_cost!(source.tile, cost) if cost
          end
          @lumber_mills = destinations.first(self.class::LUMBER_MILLS.size).map(&:id)
          @steel_mills = destinations.drop(self.class::LUMBER_MILLS.size).map(&:id)
        end

        def nonadjacent_hexes(candidates, count, chosen = [])
          return chosen if chosen.size == count
          return nil if chosen.size + candidates.size < count

          candidates.each_with_index do |candidate, index|
            adjacent_ids = candidate.neighbors.values.compact.map(&:id)
            remaining = candidates.drop(index + 1).reject { |hex| adjacent_ids.include?(hex.id) }
            result = nonadjacent_hexes(remaining, count, chosen + [candidate])
            return result if result
          end
          nil
        end

        def seed_green_cities!
          rings = rings_from(center_hex_id)
          placed = 0
          offset = r_mod(2)
          @city_corridor_sextants = [offset, offset + 2, offset + 4]
          @city_corridor_hexes = Hash.new { |hash, key| hash[key] = [] }

          GREEN_CITY_SEEDS_BY_RING.each do |ring, count|
            count.times do |slot|
              candidates = rings[ring].select { |hid| city_seed_hex?(hex_by_id(hid)) }
              desired_sextant = (@city_corridor_sextants[slot % 3] +
                CORRIDOR_SWITCHBACK_BY_RING.fetch(ring)) % 6
              hid = candidates.min_by do |candidate|
                sextant = sextant_index(center_hex_id, candidate)
                distance = [(sextant - desired_sextant) % 6, (desired_sextant - sextant) % 6].min
                [distance, r_hi]
              end
              break unless hid

              corridor = slot % 3
              lay_corridor_city!(hid, ring, corridor)
              placed += 1
            end
          end

          (GREEN_CITY_SEEDS_BY_RING.values.sum - placed).times do
            hid = GREEN_CITY_SEEDS_BY_RING.keys.flat_map { |ring| rings[ring] }
                                          .select { |id| city_seed_hex?(hex_by_id(id)) }
                                          .min_by { r_hi }
            break unless hid

            sextant = sextant_index(center_hex_id, hid)
            corridor = @city_corridor_sextants.each_index.min_by do |index|
              target = @city_corridor_sextants[index]
              [(sextant - target) % 6, (target - sextant) % 6].min
            end
            lay_corridor_city!(hid, geometric_ring(hex_by_id(hid)), corridor)
          end
        end

        def corridor_route_edges(hex, ring, corridor)
          base = @city_corridor_sextants[corridor]
          [ring - 1, ring + 1].filter_map do |target_ring|
            next unless target_ring.between?(1, 6)

            target_sextant = (base + CORRIDOR_SWITCHBACK_BY_RING.fetch(target_ring, 0)) % 6
            choices = hex.neighbors.select { |_edge, neighbor| neighbor && geometric_ring(neighbor) == target_ring }
            choices.min_by do |_edge, neighbor|
              sextant = sextant_index(center_hex_id, neighbor.id)
              [(sextant - target_sextant) % 6, (target_sextant - sextant) % 6].min
            end&.first
          end.uniq
        end

        def green_city_spec(hex, ring, corridor)
          required_edges = corridor_route_edges(hex, ring, corridor)
          specs = GREEN_CITY_EDGES.flat_map do |name, base_edges|
            6.times.filter_map do |rotation|
              exits = base_edges.map { |edge| (edge + rotation) % 6 }
              [name, rotation] if (required_edges - exits).empty?
            end
          end
          specs.min_by { r_hi } || [coin_flip ? 'FLD21' : 'FLD22', r_mod(6)]
        end

        def lay_corridor_city!(hid, ring, corridor)
          hex = hex_by_id(hid)
          name, rotation = green_city_spec(hex, ring, corridor)
          tile = lay_from_pool!(hid, name, rotation)
          ensure_mountain_upgrade_cost!(tile, terrain_cost_for(hex, :green))
          @city_corridor_hexes[corridor] << hid
        end

        def seed_brown_cities!
          rings = rings_from(center_hex_id)

          BROWN_CITY_SEEDS_BY_RING.each do |ring, count|
            placed = 0
            (0...6).each do |sextant|
              hid = seed_hex_for(rings, ring, sextant)
              next unless hid

              tile = lay_from_pool!(hid, 'FLD31', r_mod(6))
              ensure_mountain_upgrade_cost!(tile, terrain_cost_for(hex_by_id(hid), :brown))
              placed += 1
            end
            (count - placed).times do
              hid = rings[ring].select { |id| city_seed_hex?(hex_by_id(id)) }.min_by { r_hi }
              break unless hid

              tile = lay_from_pool!(hid, 'FLD31', r_mod(6))
              ensure_mountain_upgrade_cost!(tile, terrain_cost_for(hex_by_id(hid), :brown))
            end
          end
        end

        def coastal_track_spec(hex)
          coast_edges = hex.neighbors.filter_map do |edge, neighbor|
            edge if neighbor && geometric_ring(neighbor) == 6
          end
          return unless coast_edges.size == 2

          COASTAL_TRACK_EDGES.each do |name, base_edges|
            6.times do |rotation|
              rotated_edges = base_edges.map { |edge| (edge + rotation) % 6 }.sort
              return [name, rotation] if rotated_edges == coast_edges.sort
            end
          end
          nil
        end

        def seed_coastal_track!
          candidates = ring_for_flood_index(6).filter_map do |id|
            hex = hex_by_id(id)
            spec = coastal_track_spec(hex)
            [hex, spec] if blank_plain?(hex) && spec
          end
          candidates.sort_by! { r_hi }

          candidates.each do |hex, (name, rotation)|
            tile = lay_from_pool!(hex.id, name, rotation)
            ensure_mountain_upgrade_cost!(tile, terrain_cost_for(hex, :yellow))
          end
        end

        def seed_blue_waters!
          @hexes.map(&:id)
                  .select { |hid| isolated_blank_hex_id?(hid) }
                  .each do |hid|
            next unless isolated_blank_hex_id?(hid)

            lay_from_pool!(hid, 'FLOOD', 0)
          end
        end

        def seed_map_tiles!
          if symmetrical_map?
            @lumber_mills = self.class::LUMBER_MILLS
            @steel_mills = self.class::STEEL_MILLS
          else
            relocate_mills!
          end
          seed_brown_cities!
          seed_coastal_track! unless symmetrical_map?
          seed_green_cities!
          seed_blue_waters! if symmetrical_map?
          @graph&.clear_graph_for_all
        end

        def r_hi = (rand >> 16)
        def coin_flip = (r_hi & 1).zero?
        def r_mod(n) = r_hi % n
      end
    end
  end
end
