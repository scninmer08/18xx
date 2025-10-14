# frozen_string_literal: true

require_relative '../g_18_il/game'
require_relative 'meta'

module Engine
  module Game
    module G18IlSolo
      class Game < G18IL::Game
        include_meta(G18IlSolo::Meta)

        STARTING_CASH = 400
        CERT_LIMIT    = 99

        BORROW_TRAIN_ABILITY = Ability::BorrowTrain.new(
          type: 'borrow_train',
          train_types: %w[2 3 4 4+2C 5+1C 6 D],
          description: 'Must borrow train',
          desc_detail: 'While trainless, the corporation must borrow the cheapest-available train '\
                       'from the Depot when running trains.'
        )
        FORMATION_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Does not operate until IC Formation',
          desc_detail: 'IC does not operate until the IC Formation, which occurs immediately after the operating turn '\
                       ' of the corporation that completes the IC Line.'
        )

        BONUS_BY_LEVEL = {
          very_easy: 160, easy: 80, medium: 0, difficult: -80, very_difficult: -160
        }.freeze

        def show_game_cert_limit? = false

        attr_reader :robot

        def setup_preround
          create_blocking_corp
          initial_auction_lot
        end

        def setup_optional_rules
          human = @players.find { |p| p != @robot }
          level = BONUS_BY_LEVEL.keys.find { |sym| @optional_rules&.include?(sym) } || :medium
          human.cash += BONUS_BY_LEVEL[level]
        end

        def setup
          super
          @robot = Player.new(-1, 'Pullman')
          @players << @robot
          solo_seed_ic_and_subs!
          apply_subsidiary_prelays!
          nc.trains.shift # removes the Rogers train
        end

        def init_round
          round = stock_round
          @round_counter += 1
          @log << "-- #{round_description('Stock', round.round_num)} --"
          round
        end

        def new_stock_round
          round = stock_round
          @round_counter += 1
          @log << "-- #{round_description('Stock', round.round_num)} --"
          auto_sr_buys_for_robot
          round
        end

        # ----- SR auto-buys ----------------------

        def auto_sr_buys_for_robot
          robot_buy_one_ic_share
          robot_buy_up_to_two_subsidiary_shares
        end

        def robot_buy_one_ic_share
          share = @share_pool.shares.find { |s| s.corporation == ic }
          return unless share

          @share_pool.buy_shares(@robot, share, exchange: :free, allow_president_change: false)
        end

        def robot_buy_up_to_two_subsidiary_shares
          remaining = 2

          # Pass 1: subsidiaries
          remaining -= robot_buy_from_targets(@subsidiaries, remaining)
          return if remaining.zero?

          # Pass 2: other floated, non-IC corporations
          others = @corporations
                    .reject { |c| c == @ic || @subsidiaries.include?(c) || c.closed? }
                    .select(&:floated?)
          robot_buy_from_targets(others, remaining)
        end

        def robot_buy_from_targets(targets, remaining)
          return 0 if remaining <= 0

          buckets = {
            five: targets.select { |c| c.total_shares == 5 },
            ten: targets.select { |c| c.total_shares == 10 },
          }
          buckets.each_value { |arr| arr.sort_by! { |c| c.share_price&.price || 0 } }

          bought = 0
          %i[five ten].each do |kind|
            break if remaining.zero?

            buckets[kind].each do |corp|
              break if remaining.zero?

              cap = robot_share_cap_for(corp)
              next unless cap
              next if robot_current_share_count(corp) >= cap

              # Try market first, then treasury
              share_sources = [
                -> { corp.shares.select { |s| s.owner == @share_pool && s.buyable } },
                -> { corp.shares.select { |s| s.owner == corp && s.buyable } },
              ]

              share_sources.each do |source|
                source.call.each do |share|
                  break if remaining.zero?
                  break if robot_current_share_count(corp) >= cap

                  price = corp.share_price&.price || 0
                  @robot.cash += (price - @robot.cash) if @robot.cash < price

                  @share_pool.buy_shares(@robot, share, allow_president_change: false)

                  bought += 1
                  remaining -= 1
                end

                break if remaining.zero? || robot_current_share_count(corp) >= cap
              end
            end
          end

          bought
        end

        def robot_share_cap_for(corp)
          case corp.total_shares
          when 5  then 3
          when 10 then 7
          end
        end

        def robot_current_share_count(corp)
          @robot.num_shares_of(corp, ceil: false)
        end

        def round_description(name, round_number = nil)
          rn    = round_number || @round&.round_num || 1
          turn  = @turn || 1
          total = total_rounds(name)
          s  = "#{name} Round "
          s += turn.to_s unless turn.zero?
          s += '.' if total && !turn.zero?
          s += "#{rn} (of #{total})" if total
          s.strip
        end

        def robot_owner?(entity)
          return unless entity
          return unless entity.corporation?

          entity.owner == @robot
        end

        def acting_for_player(player)
          return player unless player == @robot

          acting_for_robot(current_entity)
        end

        def acting_for_robot(_operator)
          @players.find { |p| p != @robot }
        end

        def reorder_players(order = nil, log_player_order: false, silent: false)
          super
          @players.delete(@robot)
          @players << @robot
        end

        def can_par?(corporation, _entity)
          !corporation.ipoed
        end

        def operating_order
          return @corporations.select(&:floated?).sort if @ic_formation_triggered

          @corporations.select { |c| c.floated? && c != ic }.sort
        end

        def concession_ok?(_player, _corp) = true
        def finish_stock_round; end

        def next_round!
          @round =
            case @round
            when nil
              init_round
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

        def stock_round
          G18IlSolo::Round::Stock.new(self, [
            G18IL::Step::HomeToken,
            G18IL::Step::BuyNewTokens,
            G18IlSolo::Step::BuySellParShares,
          ])
        end

        def operating_round(round_num)
          G18IL::Round::Operating.new(self, [
            Engine::Step::Exchange,
            G18IL::Step::SpecialTrack,
            Engine::Step::SpecialToken,
            Engine::Step::HomeToken,
            G18IL::Step::ObsoleteTrain,
            G18IL::Step::ExchangeChoiceCorp,
            Engine::Step::DiscardTrain,
            G18IlSolo::Step::Conversion,
            G18IL::Step::PostConversionShares,
            G18IL::Step::BuyNewTokens,
            G18IlSolo::Step::IssueShares,
            G18IL::Step::SpecialBuy,
            G18IlSolo::Step::Track,
            G18IlSolo::Step::Token,
            G18IL::Step::BorrowTrain,
            G18IL::Step::CorporateSellShares,
            G18IL::Step::BuyTrainBeforeRunRoute,
            G18IlSolo::Step::Route,
            G18IlSolo::Step::Dividend,
            G18IL::Step::SpecialBuyTrain,
            G18IlSolo::Step::BuyTrain,
            G18IlSolo::Step::IcFormationCheck,
          ], round_num: round_num)
        end

        def buying_power(entity)
          return entity.cash + ic.cash if subsidiary?(entity)

          super
        end

        def player_value(player)
          return super unless player == @robot

          total = 0
          total += player.cash
          total += player.shares.select { |s| s.corporation.ipoed }.sum(&:price)
          total += ic.cash
          total
        end

        def subsidiary?(corp)
          @subsidiaries&.include?(corp)
        end

        def timeline
          base = super.dup

          sep = '-' * 260
          extra = [
            sep,
            'Token priority order:',
          ]

          plan = self.class::SUB_TOKEN_PLAN
          plan.each do |corp_id, hexes|
            extra << "#{corp_id}: #{hexes.join(', ')}"
          end

          @timeline = (base + extra).freeze
        end

        SUB_TOKEN_PLAN = {
          'P&BV' => %w[H3 E12 C18 F9 G6 C8],
          'NC' => %w[H3 E8 C18 F11 D15 B11],
          'G&CU' => %w[H3 E8 E12 C18 F3 G4 C6],
          'RI' => %w[H3 E8 E12 C18 C8 E2 F3],
          'C&A' => %w[H3 E8 E12 C18 B11 F17 C8],
          'V' => %w[H3 E8 E12 C18 F17 D15 F11],
          'WAB' => %w[H3 E8 E12 C18 H7 G10 G6],
          'C&EI' => %w[H3 E8 E12 C18 F17 G16 D16],
          'IC' => %w[H7 G10 F17 E22 E8 E12 C18],
        }.freeze

        def token_targets_for(corp)
          SUB_TOKEN_PLAN[corp.id] || []
        end

        # -------------pre-laid tiles -------------

        SUB_PRELAYS = {
          'P&BV' => [
            { hex: 'E6', tile: '58', rot: 4 },
            { hex: 'E8', tile: 'P2', rot: 0 },
            { hex: 'F5', tile: '58', rot: 5 },
            { hex: 'F9', tile: '6', rot: 2 },
            { hex: 'G6', tile: '6', rot: 2 },
            { hex: 'G8', tile: '7', rot: 0 },
          ],
          'NC' => [
            { hex: 'E10', tile: '8', rot: 4 },
            { hex: 'E12', tile: 'S2', rot: 0 },
            { hex: 'F9', tile: '5', rot: 1 },
            { hex: 'F11', tile: '6', rot: 5 },
          ],
          'G&CU' => [
            { hex: 'E2', tile: '15', rot: 5 },
            { hex: 'E4', tile: '8', rot: 1 },
            { hex: 'F3', tile: '57', rot: 2 },
            { hex: 'G4', tile: '6', rot: 2 },
          ],
          'RI' => [
            { hex: 'C6', tile: '619', rot: 2 },
            { hex: 'C8', tile: '6', rot: 3 },
            { hex: 'D5', tile: '9', rot: 1 },
            { hex: 'D9', tile: '58', rot: 2 },
          ],
          'C&A' => [
            { hex: 'B11', tile: '57', rot: 2 },
            { hex: 'C12', tile: '8', rot: 0 },
            { hex: 'C14', tile: '8', rot: 3 },
            { hex: 'D15', tile: '619', rot: 5 },
            { hex: 'E16', tile: '58', rot: 2 },
            { hex: 'F15', tile: '9', rot: 1 },
          ],
          'V' => [
            { hex: 'F17', tile: 'C12', rot: 4 },
            { hex: 'G16', tile: '14', rot: 1 },
            { hex: 'H13', tile: '8', rot: 4 },
            { hex: 'H17', tile: '9', rot: 2 },
          ],
          'WAB' => [
            { hex: 'G10', tile: 'C12', rot: 4 },
            { hex: 'H7', tile: 'K13', rot: 1 },
            { hex: 'H9', tile: '9', rot: 1 },
          ],
          'C&EI' => [
            { hex: 'F19', tile: '8', rot: 3 },
            { hex: 'G20', tile: '9', rot: 2 },
            { hex: 'G22', tile: '58', rot: 4 },
            { hex: 'H19', tile: '8', rot: 4 },
          ],
        }.freeze

        def apply_subsidiary_prelays!
          return if @subsidiaries.nil? || @subsidiaries.empty?

          @subsidiaries.each do |corp|
            specs = SUB_PRELAYS[corp.id]
            next if !specs || specs.empty?

            specs.each { |spec| lay_spec_tile!(corp, spec) }
          end
        end

        def lay_spec_tile!(_corp, spec)
          hex_id = spec[:hex] || spec['hex']
          tile_n = spec[:tile] || spec['tile']
          rot    = (spec[:rot] || spec['rot'] || 0).to_i

          hex = @hexes.find { |h| h.id == hex_id }
          tile = @tiles.find { |t| t.name == tile_n }

          tile.rotate!(rot)
          @tiles.delete(tile)
          hex.lay(tile)
          clear_border_costs_after_lay!(tile)
        end

        def clear_border_costs_after_lay!(tile)
          hex = tile.hex
          tile.borders.dup.each do |border|
            next unless border.cost

            edge     = border.edge
            neighbor = hex.all_neighbors[edge]
            next if !neighbor || !hex.targeting?(neighbor) || !neighbor.targeting?(hex)

            tile.borders.delete(border)
            inv = hex.invert(edge)
            neighbor.tile.borders.delete_if { |nb| nb.edge == inv }
          end
        end

        def ic_line_candidate(old_tile, ic_exits, color)
          candidates = @tiles.select { |t| t.color == color && upgrades_to?(old_tile, t, false) }

          candidates.each do |tile|
            6.times do |r|
              tile.rotate!(0)
              tile.rotate!(r)

              next unless (ic_exits - tile.exits).empty?

              next if old_tile.color != :white && !(old_tile.exits - tile.exits).empty?

              return [tile, r]
            end

            tile.rotate!(0)
          end

          [nil, nil]
        end

        def auto_ic_line_lay!
          return if ic_line_completed? || @ic_line_laid_this_round

          hex_id = self.class::IC_LINE_ORIENTATION.keys.find { |hid| ic_line_connections(hex_by_id(hid)) < 2 }
          return unless hex_id

          hex   = hex_by_id(hex_id)
          exits = self.class::IC_LINE_ORIENTATION[hex_id]

          color =
            case hex.tile.color
            when :white  then :yellow
            when :yellow then :green
            end
          return unless color

          new_tile, rotation = ic_line_candidate(hex.tile, exits, color)
          return unless new_tile

          @tiles.delete(new_tile)

          new_tile.rotate!(rotation)
          hex.lay(new_tile)

          clear_graph_for_entity(ic)
          action = Engine::Action::LayTile.new(ic, hex: hex, tile: new_tile, rotation: rotation)
          hex_description = hex.location_name ? "#{hex.name} (#{hex.location_name}) " : "#{hex.name} "
          @log << "IC lays tile ##{new_tile.name} with rotation #{rotation} on #{hex_description}"
          ic_line_improvement(action)
          clear_border_costs_after_lay!(new_tile)
          @ic_line_laid_this_round = true
        end

        def or_round_finished
          @ic_line_laid_this_round = nil

          super
        end

        def solo_seed_ic_and_subs!
          par_80 = @stock_market.par_prices.find { |pp| pp.price == self.class::IC_STARTING_PRICE }
          @stock_market.set_par(ic, par_80)
          ic.floatable = true
          @share_pool.buy_shares(@robot, ic.shares.first, exchange: :free)
          ic.cash = 800
          place_home_token(ic)
          ic_rest = ic.shares.reject(&:president)
          @share_pool.transfer_shares(ShareBundle.new(ic_rest), @share_pool)

          @subsidiaries = []
          picks = @stock_market.par_prices
            .select { |pp| [60, 80, 100].include?(pp.price) }
            .sort_by { |pp| -pp.price }
          sizes = [2, 5, 10]
          used  = []

          sizes.zip(picks).each do |size, par_price|
            next unless par_price

            corp = @corporations
                     .select { |c| c.total_shares == size && c != ic && !used.include?(c) }
                     .min_by { rand }

            next unless corp

            used << corp
            @subsidiaries << corp

            @stock_market.set_par(corp, par_price)

            @share_pool.buy_shares(@robot, corp.shares.first, exchange: :free)
            token_count =
              case size
              when 2 then 0
              when 5 then 1
              when 10 then 3
              end
            token_count.times { corp.tokens << Token.new(corp, price: 0) }
            place_home_token(corp)
            corp.cash = par_price.price * 2
            2.times { corp.companies.first.close! }
            assign_port_icon(corp)
            corp.add_ability(BORROW_TRAIN_ABILITY)

            @log << "#{ic.name} starts #{corp.name} at #{format_currency(par_price.price)}"
          end
        end

        def train_help(entity, runnable_trains, _routes)
          help = []
          help << 'You must run the best route available.' if entity.owner == @robot
          runnable_trains.each do |t|
            case t&.name
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

        # ---------------- IC FORMATION ----------------------

        def trigger_ic_formation!(entity)
          @log << 'IC Line is complete'
          @ic_formation_triggered = true
          @ic_formation_pending = true
          @ic_trigger_entity = entity
          return if entity == ic

          @log << "-- The Illinois Central Railroad will form at the end of #{entity.name}'s turn --"
        end

        def event_ic_formation!
          @log << '-- Event: Illinois Central Formation --'

          ic_setup
          option_cube_exchange

          finalize_ic_formation_if_ready!
        end

        def ic_setup
          ic.add_ability(self.class::STOCK_PURCHASE_ABILITY)
          ic.add_ability(self.class::TRAIN_BUY_ABILITY)
          ic.add_ability(self.class::TRAIN_LIMIT_ABILITY)
          ic.remove_ability(self.class::FORMATION_ABILITY)
          assign_port_icon(ic)
          place_home_token(ic)
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

          sync_ic_operating_state!

          if @round.entities.empty?
            @log << 'IC will operate for the first time in this operating round'
            @round.entities << ic
          else
            current_corp_index = @round.entities.index(@ic_trigger_entity) || -1

            @log << 'IC will operate for the first time in this operating round'

            ic_price = ic.share_price&.price
            live = @round.entities.select { |c| c.corporation? && c.share_price && !c.closed? }
            index_corp = live.sort.find { |c| c.share_price.price < ic_price }
            index = @round.entities.find_index(index_corp)

            if index.nil?
              @round.entities << ic
            else
              trigger_price = @ic_trigger_entity&.share_price&.price || 0
              if ic.share_price.price > trigger_price
                @round.entities.insert((current_corp_index == -1 ? index : current_corp_index) + 1, ic)
              else
                @round.entities.insert(index, ic)
              end
            end
          end
          ic.trains.sort_by!(&:price)
        end

        def or_set_finished
          if %w[4A 4B 5 6 D].include?(@phase.name)
            @corporations.each do |c|
              if (!c.floated? && !@closed_corporations.include?(c)) || subsidiary?(c)
                if c.total_shares == 2
                  convert(c)
                  if subsidiary?(c)
                    c.tokens << Token.new(c, price: 0)
                    @log << "-- #{c.name} converts from a 2-share to a 5-share corporation --"
                  end
                end
                if c.total_shares == 5 && @phase.name != '4A'
                  convert(c)
                  if subsidiary?(c)
                    2.times { c.tokens << Token.new(c, price: 0) }
                    @log << "-- #{c.name} converts from a 5-share to a 10-share corporation --"
                  end
                end
              end

              if (company = @companies.find { |comp| comp.sym == c.name })
                company.meta[:share_count] = c.total_shares
              end
            end
          end

          return unless phase.name == 'D'

          event_pullman_strike!
          event_blocking_tokens!

          @last_set = true
        end
      end
    end
  end
end
