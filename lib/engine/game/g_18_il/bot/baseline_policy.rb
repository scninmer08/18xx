# frozen_string_literal: true

# rubocop:disable Layout/LineLength, Style/MultilineBlockChain, Style/UnlessLogicalOperators

require_relative 'route_finder'
require_relative 'policy_profile'

module Engine
  module Game
    module G18IL
      module Bot
        Decision = Struct.new(:action, :reason, keyword_init: true)

        class BaselinePolicy
          ROUTES_PER_TRAIN = 20
          LONG_ROUTES_PER_TRAIN = 80
          ROUTE_COMBINATION_TIMEOUT = 10
          ISOLATED_ROUTE_PATH_TIMEOUT = 6
          ISOLATED_ROUTE_COMBINATION_TIMEOUT = 3
          ISOLATED_ROUTE_WALL_TIMEOUT = 12
          ISOLATED_ROUTE_LIMIT = 6_000
          ISOLATED_LONG_ROUTE_PATH_TIMEOUT = 20
          ISOLATED_LONG_ROUTE_COMBINATION_TIMEOUT = 10
          ISOLATED_LONG_ROUTE_WALL_TIMEOUT = 35
          ISOLATED_LONG_ROUTE_LIMIT = 20_000
          LONG_ROUTE_TRAIN_NAMES = %w[4 4+2C 5 5+1C 5+2C 6 6+1C 8 9 D].freeze
          EXACT_ROUTE_TRAIN_NAMES = (LONG_ROUTE_TRAIN_NAMES + %w[0+3C 1+3C]).freeze
          EARLY_CONCESSION_BID_CAP = 60
          LATE_CONCESSION_BID_CAP = 130
          CONCESSION_SCARCITY_PREMIUMS = {
            abundant: 0,
            modest: 5,
            tight: 15,
            scarce: 25,
          }.freeze
          CONCESSION_MIN_PLAN_BID = 10
          CONCESSION_CASH_SCALE_BASE_PLAYERS = 4
          CONCESSION_CASH_SCALE_MIN = 0.9
          CONCESSION_CASH_SCALE_MAX = 1.2
          FIRST_CONCESSION_TOP_BID = 60
          FIRST_CONCESSION_SCORE_GAP_DIVISOR = 3
          EXPENSIVE_FIRST_CONCESSION_DEFENSE_BID = 50
          CONCESSION_PLAN_SCORE_DIVISOR = 4
          CONCESSION_PRICE_ENFORCEMENT_VALUE = 5
          LAUNCH_TAKEOVER_EXPOSURE_PENALTY = 260
          LAUNCH_TAKEOVER_LOCK_BONUS = 320
          LAUNCH_TAKEOVER_UNIT_BONUS = 80
          LAUNCH_TAKEOVER_LOCK_BUY_DEPTH = 4
          SURPLUS_TWO_TRAIN_PENALTY = 120
          DELAYED_IR_MIN_PAR = 120
          HIGH_VALUE_CITY_HEXES = %w[E8 E12 H3].freeze
          CITY_UPGRADE_EXIT_REQUIREMENTS = {
            'E8' => [1, 3, 5],
          }.freeze
          CITY_UPGRADE_STRANDED_APPROACH_PENALTY = 10_000
          REVENUE_DESTINATION_VALUES = {
            'E8' => 60,
            'E12' => 60,
            'H3' => 100,
            'B17' => 100,
            'F25' => 60,
          }.freeze
          CORPORATION_REVENUE_DESTINATION_VALUES = {
            'CBQ' => { 'E8' => 160, 'E12' => 160 },
          }.freeze
          STRATEGIC_TARGET_COUNT = 2
          DESTINATION_PROGRESS_BASE = 400
          DESTINATION_PROGRESS_SCALE = 20
          TOKEN_FUTURE_VALUE_MULTIPLIER = 10
          HEALTHY_PERMANENT_FUNDING_RATIO = 0.75
          TRAIN_SUBSIDY_MINIMUM_SAVINGS = 60
          SHARE_PREMIUM_LATE_MIN_PRICE = 100
          SHARE_PREMIUM_PERMANENT_BUFFER = 80
          RUSH_DELIVERY_IMMEDIATE_PERMANENT_BONUS = 95
          ZERO_THREE_CITY_TRAIN_BONUS = 180
          ZERO_THREE_CITY_MIN_CITIES = 3
          TRAIN_FUNDING_INTENT_MATCH_BONUS = 520
          TRAIN_FUNDING_INTENT_PERMANENT_BONUS = 260
          TRAIN_FUNDING_INTENT_ZERO_THREE_CITY_BONUS = 260
          TRAIN_FUNDING_INTENT_THREE_BONUS = 320
          THREE_TRAIN_RUST_PROTECTION_BONUS = 900
          RUST_REPLACEMENT_TRAIN_BONUS = 620
          TRAILING_TRAIN_ACCELERATION_MAX_BONUS = 260
          TRAIN_ACCELERATION_RUST_BONUS = 160
          TRAIN_ACCELERATION_ROSTER_BONUS = 70
          TRAIN_ACCELERATION_LEADER_RUST_BONUS = 120
          TRAIN_ACCELERATION_VALUE_GAP_DIVISOR = 20
          DIVIDEND_TREASURY_CASH_WEIGHT = 1.0
          DIVIDEND_OWNER_CASH_WEIGHT = 1.0
          DIVIDEND_MARKET_CAP_WEIGHT = 1.0
          SCRAP_FOR_PERMANENT_BASE_LOSS_ALLOWANCE = 80
          SCRAP_FOR_PERMANENT_REVENUE_LOSS_RATIO = 0.35
          SECOND_CORPORATION_LAUNCH_BONUS = 140
          CONCESSION_LAUNCH_FUNDING_THRESHOLD = 120
          LATE_HIGH_CAPITALIZATION_BONUS = 460
          LATE_HIGH_CAPITALIZATION_MIN_PAR = 120
          LATE_HIGH_CAPITALIZATION_TARGET_SHARES = 6
          INVESTOR_MODE_PLAYER_COUNTS = (5..6).freeze
          INVESTOR_FOUNDER_COMMITMENT_BUFFER = 2
          INVESTOR_FOUNDER_MAX_SHARES = 6
          INVESTOR_FOUNDER_LAUNCH_BONUS = 520
          INVESTOR_FOUNDER_TRAIN_BONUSES = {
            '4' => 60,
            '0+3C' => 90,
            '5' => 180,
            '4+2C' => 220,
            '5+1C' => 240,
            '8' => 260,
            'D' => 300,
          }.freeze
          INVESTOR_FOUNDER_TREASURY_MARGIN_CAP = 180
          INVESTOR_FOUNDER_TREASURY_MARGIN_DIVISOR = 3
          INVESTOR_PORTFOLIO_PRIORITY = 4
          TRAIN_PRESSURE_CONCESSION_BONUS = 160
          TRAIN_PRESSURE_LAUNCH_BONUS = 320
          TRAIN_PRESSURE_HIGH_PAR_BONUS = 120
          TRAIN_PRESSURE_SHARE_PRIORITY = 2
          TRAIN_PRESSURE_TARGET_SHARES = 6
          TRAIN_PRESSURE_TARGET_TRAIN_NAMES = %w[5 4+2C 5+1C 8].freeze
          LAUNCH_TREASURY_SCORE_DIVISOR = 2
          ICC_EW_DESTINATION_VALUE = 160
          ICC_NS_DESTINATION_VALUE = 120
          ENDPOINT_PAIR_TRACK_BONUS = 260
          ENDPOINT_PAIR_TRACK_PROGRESS_DIVISOR = 6
          HIGH_VALUE_TRACK_BONUS = 250
          HIGH_VALUE_ROUTE_ACCESS_MULTIPLIER = 4
          HIGH_VALUE_TOKEN_BONUS = 300
          ENDPOINT_PAIR_TOKEN_BONUS = 220
          IC_LINE_TOKEN_BONUS = 160
          STRATEGIC_TRAIN_TRANSFER_BONUS = 360
          STRATEGIC_TRAIN_TRANSFER_FUNDING_RATIO = 0.75
          TWO_CORPORATION_TRAIN_BANK_PAIR_BONUS = 150
          EARLY_SIBLING_TRAIN_TRANSFER_BONUS = 760
          EARLY_SIBLING_TRAIN_TRANSFER_ORDER_BONUS = 240
          EARLY_SIBLING_TRAIN_TRANSFER_NAMES = %w[2 3].freeze
          CLOSURE_PAIR_BONUS = 180
          CLOSURE_LOW_PAR_BONUS = 180
          CLOSURE_SHARE_ACCUMULATION_BONUS = 3
          CLOSURE_TRAIN_STRIP_BONUS = 520
          CLOSURE_OVERTRAIN_BONUS = 260
          CLOSURE_STOCK_SALE_THRESHOLD = 40
          CLOSURE_ISSUE_SCORE_THRESHOLD = 55
          CLOSURE_INTENT_SCORE_BONUS = 35
          CLOSURE_REOPEN_CASH_DIVISOR = 3
          CLOSURE_REOPEN_TRAIN_DIVISOR = 4
          CLOSURE_REOPEN_PRIVATE_DIVISOR = 2
          CLOSURE_REOPEN_CLOSED_BONUS = 80
          CLOSURE_ACTIVE_OPERATOR_MIN_TRAINS = 2
          CLOSURE_ACTIVE_OPERATOR_MIN_REVENUE_NODES = 4
          MARKET_CLOSE_PROTECTION_BUFFER_STEPS = 3
          MARKET_CLOSE_PROTECTION_PRIORITY = 7
          MARKET_CLOSE_PROTECTION_STOCK_BONUS = 1_200
          ENDGAME_PREMIUM_SHARE_PRICE = 100
          IC_LINE_AUCTION_RESERVE_HEXES = 7
          SECOND_CONCESSION_SATURATION_RESERVE_PLAYERS = 1
          STRATEGIC_ANCHOR_TOKEN_HEXES = %w[H3 E8 E12 C18].freeze
          STRATEGIC_ANCHOR_TOKEN_BONUS = 520
          STRATEGIC_ANCHOR_DENIAL_BONUS = 260
          STRATEGIC_TOKEN_PURCHASE_SCORE = 2
          TWO_SHARE_DENIAL_BONUS = 60
          TWO_SHARE_DENIAL_STOCK_BONUS = 180
          IDLE_CASH_SHARE_BONUS = 160
          IC_SHARE_INTENT_PRIORITY = 3
          IC_PRESIDENCY_PURSUIT_PRIORITY = 7
          IC_PRESIDENCY_DEFENSE_PRIORITY = 8
          HIGH_UPSIDE_ENGINE_SHARE_PRIORITY = 3
          HIGH_UPSIDE_ENGINE_STOCK_BONUS = 520
          HIGH_UPSIDE_ENGINE_MIN_SCORE = 4
          WEAK_PERMANENT_ROUTE_SHARE_PENALTY = 260
          PERMANENT_ROUTE_REPAIR_MULTIPLIER = 2
          MERGE_WEAK_CORPORATION_BONUS = 260
          MERGE_STRONG_INDEPENDENT_PENALTY = 380
          MERGE_ACTIVE_OPERATOR_BASE_PENALTY = 220
          MERGE_ACTIVE_OPERATOR_TRAIN_PENALTY = 60
          MERGE_ACTIVE_OPERATOR_NODE_PENALTY = 30
          MERGE_ACTIVE_OPERATOR_CASH_DIVISOR = 4
          MERGE_ACTIVE_OPERATOR_MIN_PRICE = 80
          MERGE_ACTIVE_OPERATOR_MIN_REVENUE_NODES = 4
          MERGE_HEALTHY_PRICE_THRESHOLD = 100
          MERGE_HEALTHY_INDEPENDENT_BASE_PENALTY = 240
          MERGE_HEALTHY_PRICE_PREMIUM_MULTIPLIER = 4
          MERGE_HEALTHY_CASH_DIVISOR = 4
          MERGE_HEALTHY_TREASURY_DIVISOR = 4
          BOOM_CITY_UPGRADE_BONUS = 3_000
          IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_MAX_ACTIONS = 300
          IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_LIMIT = 0
          IMMEDIATE_ROUTE_REVENUE_TRACK_MULTIPLIER = 20
          ROUTE_CREATION_PROGRESS_BONUS = 600
          ROUTE_CREATION_DESTINATION_BONUS = 1_200
          URGENT_ROUTE_CREATION_BONUS = 8_000
          URGENT_ROUTE_PROGRESS_BONUS = 3_000
          IC_LINE_PROGRESS_BONUS = 300
          IC_LINE_COMPLETION_BONUS = 450
          IC_LINE_CITY_URGENCY_BONUS = 1_200
          IC_LINE_H7_URGENCY_BONUS = 1_800
          IC_LINE_FUTURE_COMPLETION_BONUS = 2_500
          IC_LINE_NEAR_COMPLETE_URGENCY_BONUS = 3_000
          IC_LINE_FINAL_HEX_URGENCY_BONUS = 6_000
          IC_LINE_LATE_PHASE_URGENCY_BONUS = 2_000
          IC_LINE_LATE_PHASES = %w[5A 4B 5B 8 D].freeze
          CORPORATION_OPENING_LINK_BONUS = 6_000
          C_EI_OPENING_TRACK_COSTS = { 'G22' => 60, 'H19' => 20, 'G20' => 20, 'F21' => 20 }.freeze
          C_EI_SECOND_LAY_RESERVE_PER_HEX = 10
          C_EI_OPENING_UPSIDE_BONUS = 125
          FORBIDDEN_PAR_PRICES = { 'IR' => [40], 'RI' => [40] }.freeze
          PRESIDENT_MAX_OWNERSHIP_PERCENT = 60
          GALENA_PRIVATE_FIT_CORPORATIONS = %w[G&CU IR RI].freeze
          WATER_PRIVATE_FIT_CORPORATIONS = %w[IR V].freeze
          CENTRAL_TOWN_HEXES = %w[E8 E12].freeze
          WATER_PRIVATE_HEXES = %w[C2 C6 D11 D15 D17 E6 E8 E10 F5 F17 F19 F21 G6 G14 G20 G22 H17 H19 H21].freeze
          PREMIUM_HOME_TOKEN_BONUSES = {
            'IR' => 90,
            'NC' => 90,
          }.freeze
          PRIVATE_VALUES = {
            'AT' => 70,
            'CIB' => 10,
            'CVCC' => 40,
            'EC' => 50,
            'EM' => 70,
            'FWC' => 45,
            'GTL' => 50,
            'ICC' => 45,
            'ISBC' => 25,
            'PO' => 20,
            'RD' => 35,
            'RE' => 85,
            'SP' => 30,
            'TS' => 45,
            'USML' => 55,
            'USY' => 35,
          }.freeze
          attr_reader :profile

          def initialize(profile: PolicyProfile.new)
            @profile = profile
            @route_cache = {}
            @hex_build_distances_cache = {}
            @first_concession_auction_baselines = {}
            @concession_launch_intents = {}
            @train_funding_intents = {}
            @closure_intents = {}
            @ic_share_intents = {}
          end

          def choose(game)
            step = game.round.active_step
            entity = decision_entity(game.round.current_entity, step)
            return Decision.new(reason: 'No active step or entity') if !step || !entity

            private_decision = private_ability_decision(game, entity)
            return private_decision if private_decision

            special_buy = optional_special_buy_decision(game, entity)
            return special_buy if special_buy

            actions = step.actions(entity)
            return Decision.new(reason: 'The active entity has no actions') if actions.empty?

            decision = auction_decision(game, step, entity, actions) ||
              presidency_funding_sale_decision(game, step, entity, actions) ||
              presidency_protection_purchase_decision(game, step, entity, actions) ||
              dump_risk_stock_sale_decision(game, step, entity, actions) ||
              concession_launch_funding_sale_decision(game, step, entity, actions) ||
              presidency_lockdown_purchase_decision(game, step, entity, actions) ||
              concession_launch_intent_stock_decision(game, step, entity, actions) ||
              strategic_stock_decision(game, step, entity, actions) ||
              president_capitalization_purchase_decision(game, step, entity, actions) ||
              closure_stock_sale_decision(game, step, entity, actions) ||
              market_close_protection_funding_sale_decision(game, step, entity, actions) ||
              market_close_protection_purchase_decision(game, step, entity, actions) ||
              president_market_share_funding_sale_decision(game, step, entity, actions) ||
              president_market_share_purchase_decision(game, step, entity, actions) ||
              ic_share_funding_sale_decision(game, step, entity, actions) ||
              ic_share_purchase_decision(game, step, entity, actions) ||
              voluntary_stock_sale_decision(game, step, entity, actions) ||
              stock_decision(game, step, entity, actions) ||
              share_purchase_decision(game, step, entity, actions) ||
              new_token_decision(game, step, entity, actions) ||
              forced_stock_sale_decision(game, step, entity, actions) ||
              conversion_decision(game, step, entity, actions) ||
              private_acquisition_decision(game, step, entity, actions) ||
              special_buy_decision(game, step, entity, actions) ||
              home_token_decision(game, step, entity, actions) ||
              track_decision(game, step, entity, actions) ||
              token_decision(game, step, entity, actions) ||
              share_issue_decision(game, step, entity, actions) ||
              corporate_share_sale_decision(step, entity, actions) ||
              emergency_share_sale_decision(game, step, entity, actions) ||
              train_decision(game, step, entity, actions) ||
              discard_train_decision(step, entity, actions) ||
              borrow_train_decision(step, entity, actions) ||
              route_extension_decision(game, step, entity, actions) ||
              scrap_train_decision(game, step, entity, actions) ||
              route_decision(game, step, entity, actions) ||
              dividend_decision(game, step, entity, actions) ||
              option_cube_exchange_decision(game, step, entity, actions) ||
              merger_compensation_decision(game, step, entity, actions) ||
              merge_decision(game, step, entity, actions) ||
              planned_obsolescence_decision(step, entity, actions) ||
              draft_decision(game, step, entity, actions) ||
              forced_choice_decision(step, entity, actions)
            return decision if decision

            # Optional decisions are declined until a policy for that decision is implemented.
            if actions.include?('pass')
              return Decision.new(
                action: Engine::Action::Pass.new(entity),
                reason: "Baseline policy passes #{step.description}",
              )
            end

            Decision.new(reason: "No baseline policy for #{actions.join(', ')}")
          end

          def closure_intent_for(game, corporation)
            return unless remembered_closure_intent?(game, corporation)

            @closure_intents[corporation.id]&.dup
          end

          private

          def private_ability_decision(game, current_entity)
            return if game.round.active_step.is_a?(G18IL::Step::ObsoleteTrain)

            companies = if current_entity.company?
                          [current_entity]
                        elsif current_entity.corporation?
                          current_entity.companies
                        else
                          []
                        end

            companies.sort_by(&:sym).each do |company|
              next if game.private_used?(company)

              usable = current_entity.company? || game.entity_can_use_company?(current_entity, company)
              next unless usable

              step = game.round.active_step(company)
              next unless step

              actions = step.actions(company)
              decision = private_company_decision(game, step, company, actions)
              return decision if decision
            end
            nil
          end

          def private_company_decision(game, step, company, actions)
            return share_premium_decision(game, step, company) if actions.include?('choose_ability')
            return special_track_decision(game, step, company) if actions.include?('lay_tile')
            return special_token_decision(game, step, company) if actions.include?('place_token')
            return train_subsidy_decision(game, step, company) if actions.include?('buy_train')

            nil
          end

          def optional_special_buy_decision(game, entity)
            return unless entity&.corporation?

            step = game.round.steps.find { |candidate| candidate.is_a?(G18IL::Step::SpecialBuy) }
            return unless step

            active_step = game.round.active_step
            if active_step != step && active_step&.blocking? && game.round.steps.index(step) >= game.round.steps.index(active_step)
              return
            end

            special_buy_decision(game, step, entity, step.actions(entity))
          end

          def share_premium_decision(game, step, company)
            owner = company.owner
            return unless company.sym == 'SP'
            return unless owner&.corporation?
            return unless share_premium_useful_now?(game, owner)

            choice = step.choices_ability(company).keys.first
            return unless choice

            Decision.new(
              action: Engine::Action::ChooseAbility.new(company, choice: choice),
              reason: "Activates #{company.name} before issuing a train-funding share",
            )
          end

          def special_track_decision(game, step, company)
            return unless step.is_a?(G18IL::Step::SpecialTrack)
            return unless step.tile_lay_available?(company)
            return unless advanced_track_useful_now?(game, company)

            owner = company.owner
            ability = step.abilities(company)
            reachable_hexes = game.graph_for_entity(owner).reachable_hexes(owner) if ability.reachable
            candidates = game.hexes.flat_map do |hex|
              next [] unless step.available_hex(company, hex)
              next [] if ability.reachable && hex.id != owner.coordinates && !reachable_hexes[hex]

              step.potential_tiles(company, hex).flat_map do |tile|
                step.legal_tile_rotations(company, hex, tile).filter_map do |rotation|
                  rotated_tile = safely_rotated_tile(tile, rotation)
                  next unless rotated_tile

                  next unless ic_line_tile_valid?(game, hex, rotated_tile)
                  next if city_upgrade_stranded_approach?(hex, rotated_tile)
                  next if permanently_stranded_revenue_approach?(game, hex, rotated_tile)
                  next unless advanced_track_candidate_allowed?(game, company, hex)

                  if ability.reachable
                    connected_edges = game.graph_for_entity(owner).connected_hexes(owner)[hex] || []
                    next if (rotated_tile.exits & connected_edges).empty?
                  end
                  cost = special_track_cost(hex, ability)
                  next if cost > owner.cash
                  next unless preserves_train_funds?(game, owner, cost)

                  score = track_candidate_score(game, hex, rotated_tile, cost, owner)
                  [hex, tile, rotation, cost, score]
                end
              end
            end
            hex, tile, rotation, _cost, score = candidates.min_by do |candidate_hex, candidate_tile, candidate_rotation,
                                                                      cost, candidate_score|
              [-candidate_score, cost, candidate_hex.id, candidate_tile.name, candidate_rotation]
            end
            return unless hex

            Decision.new(
              action: Engine::Action::LayTile.new(company, hex: hex, tile: tile, rotation: rotation),
              reason: "Uses #{company.name} to lay #{tile.name} on #{hex.id} (track score #{score})",
            )
          end

          def advanced_track_useful_now?(game, company)
            return true unless company.sym == 'AT'

            laid = game.round.num_laid_track.to_i
            return false if laid.zero?
            return true if laid >= 2

            game.round.upgraded_track
          end

          def advanced_track_candidate_allowed?(game, company, hex)
            return true unless company.sym == 'AT'

            round = game.round
            return true if round.num_laid_track.to_i >= 2

            round.upgraded_track && track_upgrade_hex?(hex)
          end

          def track_upgrade_hex?(hex)
            hex.tile.color != :white
          end

          def special_track_cost(hex, ability)
            return 0 if ability.free

            hex.tile.upgrades.sum(&:cost) + hex.tile.borders.sum { |border| border.cost || 0 }
          end

          def special_token_decision(game, step, company)
            return unless step.is_a?(G18IL::Step::SpecialToken)

            ability = step.ability(company)
            owner = company.owner
            candidates = game.hexes.flat_map do |hex|
              next [] unless step.available_hex(company, hex)

              hex.tile.cities.filter_map do |city|
                next if ability.city && ability.city != city.index

                if ability.connected
                  connected = game.token_graph_for_entity(owner).connected_nodes(owner)[city]
                  next unless connected
                end
                next unless city.tokenable?(owner, free: true, extra_slot: ability.extra_slot)

                [city, token_candidate_score(game, city, nil)]
              end
            end
            city, score = candidates.min_by { |candidate_city, candidate_score| [-candidate_score, candidate_city.hex.id] }
            return unless city

            Decision.new(
              action: Engine::Action::PlaceToken.new(company, city: city),
              reason: "Uses #{company.name} to place a token in #{city.hex.id} (token score #{score})",
            )
          end

          def train_subsidy_decision(game, step, company)
            return unless step.is_a?(G18IL::Step::SpecialBuyTrain)
            return unless company.sym == 'TS'

            owner = company.owner
            ability = game.abilities(company, :train_discount, time: step.ability_timing)
            candidates = step.buyable_trains(owner).select(&:from_depot?).flat_map do |train|
              step.train_variant_helper(train, owner).filter_map do |variant|
                face_price = variant[:price] || train.price
                price = ability.discounted_price(train, face_price)
                savings = face_price - price
                if price <= owner.cash && savings >= TRAIN_SUBSIDY_MINIMUM_SAVINGS &&
                   permanent_train_variant?(variant)
                  [train, variant, price]
                end
              end
            end
            train, variant, price = candidates.max_by do |candidate_train, candidate_variant, candidate_price|
              train_candidate_score(game, candidate_train, candidate_variant, candidate_price, nil, owner)
            end
            return unless train

            Decision.new(
              action: Engine::Action::BuyTrain.new(company, train: train, variant: variant[:name], price: price),
              reason: "Uses #{company.name} to buy #{variant[:name]} for #{price}",
            )
          end

          def decision_entity(current_entity, step)
            return current_entity unless step.is_a?(G18IL::Step::BuyTrain)
            return current_entity unless current_entity&.corporation?
            return current_entity unless current_entity.owner&.player?

            owner = current_entity.owner
            step.actions(owner).include?('sell_shares') ? owner : current_entity
          end

          def conversion_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Conversion)
            return unless actions.include?('convert')

            target_size = entity.total_shares == 2 ? 5 : 10
            projection = projected_post_conversion_funding(game, entity, target_size)
            train_price = game.depot.min_depot_price
            one_issue_proceeds = entity.share_price.price
            needs_conversion_for_train = entity.trains.empty? && entity.cash < train_price &&
              entity.cash + one_issue_proceeds < train_price
            three_train = conversion_three_train_target(game, entity, projection)
            train_pressure = conversion_train_pressure_target(game, entity, projection)
            permanent = cheapest_available_permanent_train(game)
            needs_conversion_for_permanent = permanent && !owns_permanent_train?(entity)
            funds_permanent = permanent && entity.cash < permanent[:price] &&
              entity.cash + projection[:total_proceeds] >= permanent[:price]
            return unless needs_conversion_for_train || three_train || train_pressure ||
                          needs_conversion_for_permanent || funds_permanent ||
                          profile[:conversion_values].fetch(entity.total_shares, 0).positive?

            reason = "Converts from #{entity.total_shares} to #{target_size} shares"
            if needs_conversion_for_train
              reason += ' because one share issue cannot fund its required train'
            elsif three_train
              reason += " so post-conversion purchases and issuance can fund the #{three_train[:name]} before 2-trains rust"
            elsif train_pressure
              reason += " so post-conversion purchases and issuance can pressure the market with the #{train_pressure[:name]}"
            elsif needs_conversion_for_permanent
              reason += ' to raise capital for an available permanent train'
            elsif funds_permanent
              reason += " so post-conversion purchases and issuance can fund the #{permanent[:name]} permanent train"
            end

            Decision.new(
              action: Engine::Action::Convert.new(entity),
              reason: reason,
            )
          end

          def projected_post_conversion_funding(game, corporation, target_size)
            share_percent = target_size == 5 ? 20 : 10
            new_shares = target_size == 5 ? 3 : 5
            treasury_shares = corporation.shares.count { |share| share.owner == corporation }
            reserve_shares = target_size == 10 ? 1 : 0
            available_shares = treasury_shares + new_shares - reserve_shares
            share_price = corporation.share_price.price
            holdings = projected_conversion_holdings(game, corporation, target_size)
            owner = corporation.owner
            order = game.players.rotate(game.players.index(owner) || 0)

            purchase_proceeds = order.sum do |player|
              ownership_room = (60 - holdings.fetch(player, 0)) / share_percent
              cash_room = player.cash / share_price
              cert_room = game.cert_limit(player) - game.num_certs(player)
              purchase_limit = if player == owner
                                 available_shares
                               elsif corporation.trains.any?
                                 1
                               else
                                 0
                               end
              purchases = [ownership_room, cash_room, cert_room, purchase_limit, available_shares].min.clamp(0, available_shares)
              available_shares -= purchases
              holdings[player] = holdings.fetch(player, 0) + (purchases * share_percent)
              purchases * share_price
            end
            issue_available = available_shares.positive? || reserve_shares.positive?
            issue_proceeds = issue_available ? share_price : 0
            {
              purchase_proceeds: purchase_proceeds,
              issue_proceeds: issue_proceeds,
              total_proceeds: purchase_proceeds + issue_proceeds,
            }
          end

          def conversion_three_train_target(game, entity, projection)
            return unless entity.total_shares == 2
            return unless needs_three_train_before_four?(game, entity)

            three_train_options(game, entity)
              .select { |option| entity.cash < option[:price] }
              .select { |option| entity.cash + projection[:total_proceeds] >= option[:price] }
              .min_by { |option| option[:price] }
          end

          def conversion_train_pressure_target(game, entity, projection)
            return unless entity.total_shares == 5
            return unless train_pressure_window?(game)
            return if owns_permanent_train?(entity)

            target = train_pressure_target_train(game)
            return unless target
            return unless entity.cash < target[:price]
            return unless entity.cash + projection[:total_proceeds] >= target[:price]

            target
          end

          def projected_conversion_holdings(game, corporation, target_size)
            game.players.to_h do |player|
              percent = player.shares_of(corporation).sum do |share|
                if target_size == 5
                  share.president ? 40 : 20
                else
                  share.president ? 20 : 10
                end
              end
              [player, percent]
            end
          end

          def private_acquisition_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::ConversionPrivateChoice)
            return unless actions.include?('acquire_company')

            candidates = step.eligible_private_companies.map do |candidate|
              source_value = candidate.owner == entity.owner ? profile[:private_president_bonus] : 0
              [candidate, private_value_for_corporation(game, entity, candidate) + source_value]
            end
            company, value = candidates.max_by do |candidate, candidate_value|
              [candidate_value, candidate.name]
            end
            return if !company || value < profile[:private_acquisition_threshold]

            source = company.owner == entity.owner ? 'its president' : 'the Development Pool'
            Decision.new(
              action: Engine::Action::AcquireCompany.new(entity, company: company),
              reason: "Acquires #{company.name} from #{source}",
            )
          end

          def special_buy_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::SpecialBuy)
            return unless actions.include?('special_buy')
            return unless entity.corporation?
            return if game.stl_permit?(entity)
            return unless game.stl_permit_available?
            return unless stl_reachable?(game, entity)

            permit = step.buyable_items(entity).find { |item| item.description == 'STL Permit' }
            return unless permit
            return if permit.cost > entity.cash

            Decision.new(
              action: Engine::Action::SpecialBuy.new(entity, item: permit),
              reason: "Buys an STL permit for #{permit.cost} because St. Louis is reachable",
            )
          end

          def stl_reachable?(game, entity)
            game.route_to_stl?(entity)
          end

          def train_buying_ability_preserved?(game, entity, cost)
            cash_after = entity.cash - cost
            minimum_train_price = game.depot.min_depot_price
            return cash_after >= minimum_train_price if entity.trains.empty?

            entity.cash < minimum_train_price || cash_after >= minimum_train_price
          end

          def auction_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::SelectionAuction)
            return unless actions.include?('bid')

            if step.choice_available?(entity)
              lot = game.lot_proxies.reject(&:closed?).max_by do |candidate|
                game.lots[candidate.meta[:lot_index]].sum { |company| auction_item_value(game, entity, company) }
              end
              return unless lot

              return Decision.new(
                action: Engine::Action::Bid.new(entity, company: lot, price: 0),
                reason: "Chooses #{lot.name}, the more valuable Big Lot",
              )
            end

            if step.auctioning
              company = auction_target(game, step)
              minimum = step.min_bid(company)
              value = auction_value(game, entity, company, step: step)
              if minimum <= value
                remember_concession_launch_intent(game, entity, company, step) if company.meta&.[](:type) == :concession

                return Decision.new(
                  action: Engine::Action::Bid.new(entity, company: company, price: minimum),
                  reason: "Bids #{minimum} for #{company.name}, valued at #{value}",
                )
              end

              return unless actions.include?('pass')

              return Decision.new(
                action: Engine::Action::Pass.new(entity),
                reason: "Concedes the auction for #{company.name} above its value of #{value}",
              )
            end

            affordable_companies = step.companies
              .select { |candidate| step.may_bid?(candidate) }
              .select { |candidate| auction_startable?(game, entity, candidate, step: step) }
              .filter_map do |candidate|
                next if candidate.meta&.[](:type) == :concession && !concession_auction_plan(game, entity, candidate, step)

                minimum = step.min_bid(candidate)
                value = auction_value(game, entity, candidate, step: step)
                [candidate, minimum, value] if minimum <= value
              end
            company = random_best_by(game, affordable_companies) do |_candidate, candidate_minimum, candidate_value|
              [candidate_value - candidate_minimum, candidate_value]
            end
            return unless company

            company, minimum, value = company
            remember_concession_launch_intent(game, entity, company, step) if company.meta&.[](:type) == :concession

            Decision.new(
              action: Engine::Action::Bid.new(entity, company: company, price: minimum),
              reason: "Opens bidding at #{minimum} for #{company.name}, valued at #{value}",
            )
          end

          def auction_target(game, step)
            step.auctioning == :turn ? game.lot_choice_proxy : step.auctioning
          end

          def auction_startable?(game, player, company, step: nil)
            return private_useful_to_player?(game, player, company) if company.meta&.[](:type) == :private
            return concession_auction_startable?(game, player, company, step: step) if company.meta&.[](:type) == :concession

            true
          end

          def concession_auction_startable?(game, player, company, step: nil)
            corporation = game.corporation_by_id(company.sym)
            return false unless corporation
            return false if corporation.ipoed
            return false if game.num_certs(player) >= game.cert_limit(player)
            return false if player.companies.any? { |candidate| candidate == company || candidate.id == company.id }
            return false if opening_investor_preferred?(game, player)
            return false if concession_opening_cost(game, player, company).infinite?

            owned = player.companies.select { |candidate| candidate.meta&.[](:type) == :concession && !candidate.closed? }
            return true if owned.empty?
            return false if owned.size >= profile[:max_concession_plan_size]
            unless second_corporation_bailout_motive?(game, player) || train_pressure_concession_motive?(game, player, corporation)
              return false if second_concession_saturated?(game, player)
            end

            second_concession_plan_value(game, player, company, bid_price: step&.min_bid(company).to_i).positive?
          end

          def first_concession_baseline_score(game, player, step, company)
            key = [game.object_id, step&.object_id || game.round&.object_id, game.turn, player.id]
            @first_concession_auction_baselines[key] ||= first_concession_baseline_candidates(game, player, step, company)
              .map { |candidate| concession_opening_corporation_score(game, player, candidate) }
              .max
              .to_i
          end

          def first_concession_baseline_candidates(game, player, step, company)
            candidates = game.companies
            candidates += step.companies if step&.respond_to?(:companies)
            candidates = (candidates + [company]).uniq
            candidates.select do |candidate|
              candidate.meta&.[](:type) == :concession &&
                !candidate.closed? &&
                auction_startable?(game, player, candidate, step: step)
            end
          end

          def second_concession_saturated?(game, player)
            return false if game.players.size <= 2

            committed_players = game.players.count do |candidate|
              concession_count = candidate.companies.count do |company|
                company.meta&.[](:type) == :concession && !company.closed?
              end
              concession_count >= profile[:max_concession_plan_size] || (candidate == player && concession_count.positive?)
            end

            committed_players >= game.players.size - SECOND_CONCESSION_SATURATION_RESERVE_PLAYERS
          end

          def auction_value(game, player, company, step: nil)
            item_value = auction_item_value(game, player, company)
            return 0 unless item_value.positive?

            value = item_value
            value += auction_preference(player, company) unless company.meta[:type] == :concession
            if company.meta[:type] == :concession
              value = concession_auction_value(game, player, company, item_value, step)
              value = [value, concession_bid_cap(game, company)].min
            end
            reserve = if ic_share_proxy?(company)
                        0
                      elsif company.meta[:type] == :concession
                        concession_auction_reserve(game, player, company)
                      elsif company.meta[:type] == :private
                        private_auction_reserve(game, player)
                      else
                        profile[:auction_cash_reserve]
                      end
            reserve = [reserve, ic_auction_cash_reserve(game, player)].max unless ic_share_proxy?(company)
            budget = [player.cash - reserve, 0].max
            [value, budget].min - ([value, budget].min % game.class::MIN_BID_INCREMENT)
          end

          def concession_auction_value(game, player, company, raw_value, step)
            return 0 if opening_investor_preferred?(game, player)

            alternatives = available_concession_alternatives(game, player, step, company)
            bid_price = step&.min_bid(company).to_i
            plan_cash = concession_plan_available_cash(game, player, company, bid_price)
            founder_pivot = investor_founder_concession_candidate?(game, player, company)
            if founder_pivot
              corporation = game.corporation_by_id(company.sym)
              return concession_price_enforcement_value(game, player, company) unless
                investor_founder_launch_par(game, player, corporation, available_cash: plan_cash)
            end
            with_plan = if founder_pivot
                          [company]
                        else
                          best_concession_opening_plan(
                            game,
                            player,
                            alternatives,
                            required: [company],
                            available_cash: plan_cash,
                          )
                        end
            return concession_price_enforcement_value(game, player, company) unless with_plan

            with_plan_score = concession_opening_plan_score(game, player, with_plan)
            if first_concession?(player)
              first_concession_score = concession_opening_corporation_score(game, player, company)
              best_score = first_concession_baseline_score(game, player, step, company)
              return concession_price_enforcement_value(game, player, company) unless best_score.positive?

              score_gap = [best_score - first_concession_score, 0].max
              top_bid = founder_pivot ? concession_bid_cap(game, company) : FIRST_CONCESSION_TOP_BID
              value = top_bid - (score_gap / FIRST_CONCESSION_SCORE_GAP_DIVISOR.to_f).round
              value = [[value, CONCESSION_MIN_PLAN_BID].max, top_bid].min
              value = defensible_first_concession_bid_value(game, player, alternatives, company, value)
              return [value, raw_value].min
            end

            without_plan = best_concession_opening_plan_score(game, player, alternatives, excluded: [company])
            plan_delta = [with_plan_score - without_plan, 0].max
            return concession_price_enforcement_value(game, player, company) unless plan_delta.positive?

            value = CONCESSION_MIN_PLAN_BID +
              concession_scarcity_premium(game, alternatives) +
              (plan_delta / CONCESSION_PLAN_SCORE_DIVISOR.to_f).round
            scaled_concession_auction_value(game, value, raw_value)
          end

          def concession_auction_reserve(game, player, company)
            opening = concession_opening_cost(game, player, company)
            return opening if opening.infinite?

            protected = minimum_concession_launch_cash_required(game, player, company, available_cash: player.cash)
            [protected || opening, opening].max
          end

          def scaled_concession_auction_value(game, value, raw_value)
            scaled = (value * player_count_concession_cash_scale(game)).round
            [scaled, raw_value].min
          end

          def player_count_concession_cash_scale(game)
            starting_cash = game.class::STARTING_CASH
            base = starting_cash.fetch(CONCESSION_CASH_SCALE_BASE_PLAYERS)
            cash = starting_cash.fetch(game.players.size, base)
            scale = Math.sqrt(cash / base.to_f)

            [[scale, CONCESSION_CASH_SCALE_MIN].max, CONCESSION_CASH_SCALE_MAX].min
          end

          def remember_concession_launch_intent(game, player, company, step)
            plan = concession_auction_plan(game, player, company, step)
            return unless plan

            @concession_launch_intents[player.id] = {
              turn: game.turn,
              corporations: plan.map(&:sym),
              defense: concession_launch_intent_defense(game, player, company, step),
            }
          end

          def concession_launch_intent_defense(game, player, company, step)
            return :normal unless first_concession?(player)
            return :normal unless step&.min_bid(company).to_i >= EXPENSIVE_FIRST_CONCESSION_DEFENSE_BID
            return :normal unless concession_needs_expensive_takeover_defense?(game, company)

            :expensive_first_concession
          end

          def concession_auction_plan(game, player, company, step)
            alternatives = available_concession_alternatives(game, player, step, company)
            bid_price = step&.min_bid(company).to_i
            available_cash = concession_plan_available_cash(game, player, company, bid_price)
            if investor_founder_concession_candidate?(game, player, company)
              corporation = game.corporation_by_id(company.sym)
              return [company] if investor_founder_launch_par(
                game,
                player,
                corporation,
                available_cash: available_cash,
              )

              return
            end
            plan = best_concession_opening_plan(
              game,
              player,
              alternatives,
              required: [company],
              available_cash: available_cash,
            )
            unless plan
              corporation = game.corporation_by_id(company.sym)
              return [company] if train_pressure_concession_motive?(game, player, corporation) &&
                train_pressure_launch_reachable?(game, player, corporation, available_cash: player.cash - bid_price)

              return
            end
            return plan if first_concession?(player)

            without_plan = best_concession_opening_plan_score(game, player, alternatives, excluded: [company])
            delta = concession_opening_plan_score(game, player, plan) - without_plan
            delta.positive? ? plan : nil
          end

          def concession_plan_available_cash(game, player, company, bid_price)
            available_cash = player.cash - bid_price
            return available_cash unless investor_founder_concession_candidate?(game, player, company)

            available_cash + investor_founder_sale_capacity(game, player)
          end

          def opening_investor_preferred?(game, player)
            return false unless presidency_free_investor_mode?(game, player)
            return true if game.turn > 1

            available = game.companies.select do |company|
              company.meta&.[](:type) == :concession && !company.closed? && !company.owner&.player?
            end
            committed = game.players.reject { |candidate| candidate == player }.flat_map do |candidate|
              candidate.companies.select do |company|
                company.meta&.[](:type) == :concession && !company.closed?
              end
            end
            return false if available.empty? || committed.empty?

            best_available = available.map do |company|
              concession_opening_corporation_score(game, player, company)
            end.max.to_i
            best_committed = committed.map do |company|
              concession_opening_corporation_score(game, player, company)
            end.max.to_i

            best_available < best_committed
          end

          def presidency_free_investor_mode?(game, player)
            return false if phase_4a_or_later?(game)
            return false if player_has_concession?(player)

            presidency_free_investor?(game, player)
          end

          def investor_founder_pivot?(game, player)
            return false unless phase_4a_or_later?(game)
            return false unless INVESTOR_MODE_PLAYER_COUNTS.cover?(game.players.size)
            return false if player_has_presidency?(game, player)
            return true if player_has_concession?(player)

            operator_commitment_count(game, except: player) >= investor_founder_commitment_threshold(game)
          end

          def investor_founder_commitment_threshold(game)
            [game.players.size - INVESTOR_FOUNDER_COMMITMENT_BUFFER, 3].max
          end

          def presidency_free_investor?(game, player)
            return false unless INVESTOR_MODE_PLAYER_COUNTS.cover?(game.players.size)
            return false if player_has_presidency?(game, player)

            operator_commitment_count(game, except: player) >= game.players.size - 1
          end

          def player_has_presidency?(game, player)
            game.corporations.any? { |corporation| corporation.ipoed && corporation.owner == player }
          end

          def player_has_concession?(player)
            player.companies.any? { |company| company.meta&.[](:type) == :concession && !company.closed? }
          end

          def operator_commitment_count(game, except: nil)
            game.players.count do |player|
              next false if player == except

              player_has_presidency?(game, player) || player_has_concession?(player)
            end
          end

          def investor_founder_concession_candidate?(game, player, company)
            return false unless investor_founder_pivot?(game, player)
            return false unless company&.meta&.[](:type) == :concession

            corporation = game.corporation_by_id(company.sym)
            corporation && !corporation.ipoed && (!company.owner || company.owner == player)
          end

          def defensible_first_concession_bid_value(game, player, alternatives, company, value)
            return value unless value >= EXPENSIVE_FIRST_CONCESSION_DEFENSE_BID
            return value unless concession_needs_expensive_takeover_defense?(game, company)

            increment = game.class::MIN_BID_INCREMENT
            bid = value - (value % increment)
            while bid >= CONCESSION_MIN_PLAN_BID
              return bid if best_concession_opening_plan(
                game,
                player,
                alternatives,
                required: [company],
                available_cash: player.cash - bid,
                defense: :expensive_first_concession,
              )

              bid -= increment
            end

            concession_price_enforcement_value(game, player, company)
          end

          def concession_needs_expensive_takeover_defense?(game, company)
            corporation = game.corporation_by_id(company.sym)
            corporation&.total_shares.to_i > 2
          end

          def first_concession?(player)
            player.companies.none? { |company| company.meta&.[](:type) == :concession && !company.closed? }
          end

          def available_concession_alternatives(game, player, step, company)
            candidates =
              if step
                step.companies
              else
                game.companies
              end
            candidates = (candidates + [company]).uniq
            candidates.select do |candidate|
              candidate.meta&.[](:type) == :concession &&
                !candidate.closed? &&
                !candidate.owner&.player? &&
                auction_startable?(game, player, candidate, step: step)
            end
          end

          def concession_scarcity_premium(game, concessions)
            demand = game.players.count do |player|
              player.companies.none? { |company| company.meta&.[](:type) == :concession }
            end
            surplus = concessions.size - demand
            case surplus
            when 2
              CONCESSION_SCARCITY_PREMIUMS[:modest]
            when 1
              CONCESSION_SCARCITY_PREMIUMS[:tight]
            else
              surplus <= 0 ? CONCESSION_SCARCITY_PREMIUMS[:scarce] : CONCESSION_SCARCITY_PREMIUMS[:abundant]
            end
          end

          def best_concession_opening_plan_score(game, player, concessions, required: [], excluded: [], available_cash: player.cash,
                                                 defense: :normal)
            plan = best_concession_opening_plan(
              game,
              player,
              concessions,
              required: required,
              excluded: excluded,
              available_cash: available_cash,
              defense: defense,
            )
            plan ? concession_opening_plan_score(game, player, plan) : 0
          end

          def best_concession_opening_plan(game, player, concessions, required: [], excluded: [], available_cash: player.cash,
                                           defense: :normal)
            owned = player.companies.select { |company| company.meta&.[](:type) == :concession && !company.closed? }
            required = (owned + required).uniq
            candidates = (owned + concessions).uniq - excluded
            return unless (required - candidates).empty?

            max_size = [profile[:max_concession_plan_size], candidates.size].min
            return if required.size > max_size

            plans = (1..max_size).flat_map { |size| candidates.combination(size).to_a }
            plans
              .select { |plan| (required - plan).empty? }
              .filter_map do |plan|
                executable_concession_opening_plan(game, player, plan, available_cash: available_cash, defense: defense)
              end
              .max_by { |plan| concession_opening_plan_score(game, player, plan) }
          end

          def concession_opening_plan_affordable?(game, player, plan, available_cash: player.cash)
            !executable_concession_opening_plan(game, player, plan, available_cash: available_cash).nil?
          end

          def executable_concession_opening_plan(game, player, plan, available_cash:, defense: :normal)
            plan.permutation.find do |ordered_plan|
              remaining_cash = available_cash
              ordered_plan.all? do |company|
                cost = minimum_concession_launch_cash_required(
                  game,
                  player,
                  company,
                  available_cash: remaining_cash,
                  defense: defense,
                )
                next false unless cost

                remaining_cash -= cost
                remaining_cash >= 0
              end
            end
          end

          def minimum_concession_launch_cash_required(game, player, company, available_cash:, defense: :normal)
            corporation = game.corporation_by_id(company.sym)
            return unless corporation
            return expensive_first_concession_launch_cash_required(game, player, corporation, available_cash) if
              defense == :expensive_first_concession

            minimum_launch_cash_required_for_prices(
              game,
              player,
              corporation,
              bot_par_prices(game.par_prices, corporation),
              available_cash: available_cash,
              protect_presidency: true,
              allow_unprotected: false,
            )
          end

          def expensive_first_concession_launch_cash_required(game, player, corporation, available_cash)
            bot_par_prices(game.par_prices, corporation).map(&:price).sort.filter_map do |par|
              required = expensive_first_concession_launch_cash_required_at_par(corporation, par)
              next unless required <= available_cash
              next unless launch_can_fund_train?(game, player, corporation, par, player_cash: available_cash)
              next if delayed_launch_preferred?(game, player, corporation, par)

              required
            end.min
          end

          def expensive_first_concession_launch_cash_required_at_par(corporation, par)
            units = corporation.presidents_percent / corporation.share_percent
            units = [units, expensive_first_concession_presidency_target_units(corporation, par)].max
            units * par
          end

          def expensive_first_concession_presidency_target_units(corporation, par)
            return corporation.presidents_percent / corporation.share_percent if corporation.total_shares <= 2
            return 3 unless corporation.total_shares == 10

            return 5 if par <= 40
            return 4 if par <= 60

            3
          end

          def concession_opening_plan_score(game, player, plan)
            corporation_scores = plan.map { |company| concession_opening_corporation_score(game, player, company) }
            corporation_scores.sum + concession_pair_synergy_score(game, plan)
          end

          def concession_opening_corporation_score(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            return 0 unless corporation

            profile_base = profile[:concession_values].fetch(company.meta[:share_count], 30)
            private_score = concession_private_value_score(game, player, corporation)
            treasury_score = corporation.cash / 4
            train_score = corporation.trains.sum(&:price) / 8
            launch_score = concession_opening_cost(game, player, company).infinite? ? -120 : 30
            strategic_score = concession_strategic_value(game, corporation)
            denial_score = two_share_concession_denial_score(game, player, corporation)
            founder_score = investor_founder_concession_bonus(game, player, company)

            profile_base + treasury_score + train_score + private_score +
              launch_score + strategic_score + denial_score + founder_score
          end

          def two_share_concession_denial_score(game, player, corporation)
            return 0 unless %w[IR NC].include?(corporation.id)

            sibling = game.corporation_by_id(corporation.id == 'IR' ? 'NC' : 'IR')
            return 0 unless sibling

            if game.players.reject { |candidate| candidate == player }.any? do |candidate|
              candidate.companies.any? { |company| company.id == sibling.id } || sibling.owner == candidate
            end
              TWO_SHARE_DENIAL_BONUS
            else
              0
            end
          end

          def concession_private_value_score(game, player, corporation)
            case corporation.total_shares
            when 10
              attached_private_value(game, corporation)
            when 5
              best_available_private_value(game, player, corporation, :A)
            when 2
              best_available_private_value(game, player, corporation, :B) +
                best_available_private_value(game, player, corporation, :A)
            else
              0
            end
          end

          def attached_private_value(game, corporation)
            corporation.companies.sum do |private_company|
              next 0 unless private_company.meta&.[](:type) == :private

              private_value_for_corporation(game, corporation, private_company)
            end
          end

          def best_available_private_value(game, player, corporation, private_class)
            available_private_options(game, player, private_class)
              .map { |private_company| private_value_for_corporation(game, corporation, private_company) }
              .max
              .to_i
          end

          def available_private_options(game, player, private_class)
            privates = development_pool_private_class(game, private_class)
            if player&.player?
              privates += player.companies.select do |company|
                company.meta&.[](:type) == :private && company.meta[:class] == private_class
              end
            end

            privates.uniq.reject { |company| company.closed? || game.private_used?(company) }
          end

          def development_pool_private_class(game, private_class)
            game.development_pool_privates.select { |company| company.meta[:class] == private_class }
          end

          def corporation_opening_strategic_score(game, corporation)
            coordinates = Array(corporation.coordinates)
            score = coordinates.sum { |hex_id| REVENUE_DESTINATION_VALUES.fetch(hex_id, 0) / 2 }
            score += 35 if (coordinates & HIGH_VALUE_CITY_HEXES).any?
            score += 25 if (coordinates & game.class::IC_LINE_CITY_HEXES).any?
            score += 20 if corporation.total_shares == 10
            score += 10 if corporation.total_shares == 5
            score += C_EI_OPENING_UPSIDE_BONUS if corporation.id == 'C&EI'
            score -= c_ei_required_opening_capital(game, corporation) / 20 if corporation.id == 'C&EI'
            score
          end

          def concession_strategic_value(game, corporation)
            corporation_opening_strategic_score(game, corporation) +
              PREMIUM_HOME_TOKEN_BONUSES.fetch(corporation.id, 0)
          end

          def concession_pair_synergy_score(game, plan)
            return 0 if plan.size < 2

            corporations = plan.filter_map { |company| game.corporation_by_id(company.sym) }
            score = 20
            score += 20 if corporations.map(&:total_shares).uniq.size > 1
            score += private_class_pair_synergy(game, corporations)
            score += galena_private_pair_synergy(corporations)
            score += two_corporation_train_bank_pair_synergy(corporations)
            score += closure_pair_synergy_score(game, corporations)
            score -= geographic_overlap_penalty(corporations)
            score
          end

          def two_corporation_train_bank_pair_synergy(corporations)
            corporations.combination(2).sum do |first, second|
              two_corporation_train_bank_pair?(first, second) ? TWO_CORPORATION_TRAIN_BANK_PAIR_BONUS : 0
            end
          end

          def two_corporation_train_bank_pair?(first, second)
            low_capital, support = [first, second].sort_by(&:total_shares)

            low_capital.total_shares == 2 && support.total_shares >= 5
          end

          def closure_pair_synergy_score(game, corporations)
            return 0 unless profile[:closure_strategy_weight].positive?

            source = corporations.find { |corporation| closure_source_candidate_score(game, corporation).positive? }
            support = corporations.find { |corporation| corporation != source && closure_support_candidate?(corporation) }
            return 0 unless source && support

            CLOSURE_PAIR_BONUS * profile[:closure_strategy_weight] / 100
          end

          def private_class_pair_synergy(game, corporations)
            classes = corporations.flat_map do |corporation|
              corporation.companies.filter_map do |company|
                company.meta[:class] if company.meta&.[](:type) == :private
              end
            end.uniq
            classes |= [:A] if corporations.any? { |corporation| corporation.total_shares == 10 } &&
              development_pool_private_class(game, :A).any?
            classes |= [:B] if corporations.any? { |corporation| corporation.total_shares <= 5 } &&
              development_pool_private_class(game, :B).any?
            classes.size * 15
          end

          def galena_private_pair_synergy(corporations)
            fwc_owner = corporations.find do |corporation|
              corporation.companies.any? { |company| company.id == 'FWC' }
            end
            return 0 unless fwc_owner
            return 0 if GALENA_PRIVATE_FIT_CORPORATIONS.include?(fwc_owner.id)

            corporations.any? { |corporation| GALENA_PRIVATE_FIT_CORPORATIONS.include?(corporation.id) } ? 25 : 0
          end

          def geographic_overlap_penalty(corporations)
            homes = corporations.map { |corporation| Array(corporation.coordinates).first }.compact
            return 0 if homes.size < 2

            homes.uniq.size < homes.size ? 25 : 0
          end

          def concession_bid_cap(game, company)
            corporation = game.corporation_by_id(company.sym)
            return EARLY_CONCESSION_BID_CAP unless corporation

            base = if permanent_train_near?(game) || game.depot.upcoming.reject(&:reserved).first&.name.to_i >= 4
                     LATE_CONCESSION_BID_CAP
                   else
                     EARLY_CONCESSION_BID_CAP
                   end
            base += 20 if corporation.id == 'IR' && permanent_train_near?(game)
            base
          end

          def concession_opening_cost(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            return player_cannot_open_cost unless corporation

            if investor_founder_concession_candidate?(game, player, company)
              sale_capacity = investor_founder_sale_capacity(game, player)
              plan = investor_founder_launch_plan(
                game,
                player,
                corporation,
                available_cash: player.cash + sale_capacity,
              )
              return player_cannot_open_cost unless plan

              required_cash = plan[:required_cash] - sale_capacity
              return [required_cash, 0].max
            end

            dump_proceeds = great_share_supply?(game, player) ? 0 : forecast_presidency_dump_proceeds(game, player)
            pressure_required = train_pressure_launch_cash_required(game, player, corporation)
            pressure_proceeds = train_pressure_launch_sale_capacity(game, player, corporation)
            if pressure_required && player.cash + pressure_proceeds >= pressure_required
              return [pressure_required - pressure_proceeds, 0].max
            end

            projected_player_cash = player.cash + [dump_proceeds, pressure_proceeds].max
            minimum_par = bot_par_prices(game.par_prices, corporation)
              .map(&:price)
              .sort
              .find do |par|
                launch_can_fund_train?(game, player, corporation, par, player_cash: projected_player_cash)
              end
            return player_cannot_open_cost unless minimum_par

            required = minimum_par * 2
            [required - dump_proceeds, 0].max
          end

          def launch_can_fund_train?(game, player, corporation, par, player_cash: player.cash)
            return true if corporation.trains.any?

            train_price = projected_launch_train_price(game)
            cash = corporation.cash + (2 * par)
            cash -= launch_token_cost(game, corporation)
            return true if cash >= train_price

            if late_high_capitalization_launch?(game, player, corporation) && par >= LATE_HIGH_CAPITALIZATION_MIN_PAR
              president_share_count = corporation.presidents_percent / corporation.share_percent
              president_cash = player_cash - (president_share_count * par)
              extra_president_shares = [
                LATE_HIGH_CAPITALIZATION_TARGET_SHARES - president_share_count,
                president_cash / par,
              ].min.clamp(0, LATE_HIGH_CAPITALIZATION_TARGET_SHARES)
              cash += extra_president_shares * par
              cash += par
              return true if cash >= train_price
            end

            if corporation.total_shares < 10
              # A conversion offers at least one token. Plan to buy it, one share with
              # the president's remaining cash, and issue one share. Do not assume that
              # the other bots will cooperate by buying treasury shares.
              cash -= launch_token_unit_cost
              president_cash = player_cash - (2 * par)
              cash += par if president_cash >= par
              cash += par
            elsif corporation.shares.any? { |share| share.owner == corporation } ||
                  game.reserved_share_for(corporation)&.owner == corporation
              cash += par
            end

            cash >= train_price
          end

          def forecast_presidency_dump_proceeds(game, player)
            dumper_index = game.players.index(player)
            proceeds = game.corporations.filter_map do |corporation|
              next unless corporation.owner == player
              next unless weak_stock_corporation?(game, corporation)
              next unless game.players.each_with_index.any? do |candidate, index|
                candidate != player && index > dumper_index &&
                  candidate.shares_of(corporation).sum(&:percent) >= corporation.presidents_percent
              end

              holding = player.shares_of(corporation).sum(&:percent)
              game.bundles_for_corporation(player, corporation)
                .select { |bundle| holding - bundle.percent <= corporation.share_percent }
                .max_by(&:price)&.price
            end
            proceeds.max || 0
          end

          def great_share_supply?(game, player)
            shares = (game.corporations.flat_map(&:shares) + game.share_pool.shares).uniq
            shares.count do |share|
              corporation = share.corporation
              next false unless corporation.ipoed && financially_healthy_corporation?(game, corporation)
              next false if share.owner == player || share.owner&.player?

              share.buyable && share.to_bundle.price <= player.cash
            end >= 2
          end

          def c_ei_required_opening_capital(game, corporation)
            remaining_track = C_EI_OPENING_TRACK_COSTS.select do |hex_id, _cost|
              game.hex_by_id(hex_id).tile.color == :white
            end
            track_reserve = remaining_track.values.sum +
              (remaining_track.size * C_EI_SECOND_LAY_RESERVE_PER_HEX)
            token_reserve = corporation.ipoed ? 0 : launch_token_cost(game, corporation)
            trains_needed = [2 - corporation.trains.size, 0].max
            train_reserve = projected_depot_train_prices(game, trains_needed).sum
            token_reserve + track_reserve + train_reserve
          end

          def projected_depot_train_prices(game, count)
            game.depot.upcoming.reject(&:reserved).first(count).map do |train|
              train.variants.values.map { |variant| variant[:price] || train.price }.min
            end
          end

          def projected_launch_train_price(game)
            upcoming = game.depot.upcoming.reject(&:reserved)
            current = upcoming.first
            return game.depot.min_depot_price unless current

            next_rank = upcoming.find { |train| train.name != current.name }
            train = next_rank || current
            train.variants.values.map { |variant| variant[:price] || train.price }.min
          end

          def launch_token_cost(game, corporation)
            return 0 if game.closed_corporations.include?(corporation)

            case corporation.total_shares
            when 2
              0
            when 5
              launch_token_unit_cost
            when 10
              launch_token_unit_cost * 2
            else
              raise GameError, "Unexpected corporation share count: #{corporation.total_shares}"
            end
          end

          def launch_token_unit_cost
            ::Engine::Game::G18IL::Game::TOKEN_COST
          end

          def bot_par_prices(prices, corporation)
            forbidden = FORBIDDEN_PAR_PRICES.fetch(corporation.id, [])
            prices.reject { |price| forbidden.include?(price.price) }
          end

          def player_cannot_open_cost
            Float::INFINITY
          end

          def auction_preference(player, company)
            score = 5381
            "#{player.id}:#{company.id}".each_byte { |byte| score = ((score << 5) + score) ^ byte }
            ((score % 5) - 2) * 5
          end

          def auction_item_value(game, player, company)
            case company.meta[:type]
            when :lot_choice
              80
            when :concession
              if player.companies.any? { |candidate| candidate.meta[:type] == :concession }
                return second_concession_value(game, player, company)
              end

              concession_value(game, player, company)
            when :private
              private_value(game, player, company)
            when :share, :presidents_share
              ic_share_value(game, company)
            else
              0
            end
          end

          def ic_share_proxy?(company)
            %i[share presidents_share].include?(company.meta[:type])
          end

          def ic_share_value(game, company)
            ic = game.ic
            return company.value unless ic&.share_price

            certificate_units = company.meta[:type] == :presidents_share ? 2 : 1
            projected_ic_share_value(game, certificate_units)
          end

          def projected_ic_share_value(game, certificate_units = 1)
            ic = game.ic
            return 0 unless ic&.share_price

            current = ic.share_price
            projected = current
            jump_count = projected_ic_jump_count(game, ic)
            jump_prices = Array.new(jump_count) do
              projected = game.stock_market.find_relative_share_price(projected, ic, :right)
              projected.price
            end
            dividends = ([current.price] + jump_prices).first(jump_count).sum { |price| price / 10.0 }
            route_bonus = ic_route_ceiling_bonus(game, ic)

            ((projected.price + dividends + route_bonus) * certificate_units).floor
          end

          def projected_ic_jump_count(game, ic)
            count = 2
            count += 1 if cheapest_available_permanent_train(game) || permanent_train_near?(game)
            count += 1 if endpoint_pair_groups(game, ic).positive?
            [count, 4].min
          end

          def permanent_train_near?(game)
            game.depot.upcoming.reject(&:reserved).first(3).any? do |train|
              train.rusts_on.nil? && train.obsolete_on.nil?
            end
          end

          def ic_route_ceiling_bonus(game, ic)
            groups = endpoint_pair_groups(game, ic)
            permanent = owns_permanent_train?(ic) || cheapest_available_permanent_train(game)
            (groups * (permanent ? 35 : 20))
          end

          def concession_value(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            return 0 unless corporation

            value = profile[:concession_values].fetch(company.meta[:share_count], 30)
            value += concession_strategic_value(game, corporation)
            value += closure_source_candidate_score(game, corporation, player: player)
            value += closure_reopen_package_value(game, corporation)
            value += corporation.cash / 2
            value += corporation.trains.sum(&:price) / 4
            value += concession_private_value_score(game, player, corporation)
            value += train_pressure_concession_value(game, player, corporation)
            value += investor_founder_concession_bonus(game, player, company)
            presidencies = game.corporations.count { |candidate| candidate.ipoed && candidate.owner == player }
            value -= presidencies * profile[:presidency_penalty]
            value
          end

          def second_concession_value(game, player, company)
            plan_value = second_concession_plan_value(game, player, company)
            return plan_value if plan_value.positive?

            concession_price_enforcement_value(game, player, company)
          end

          def second_concession_plan_value(game, player, company, bid_price: 0)
            corporation = game.corporation_by_id(company.sym)
            return 0 unless corporation
            return 0 if corporation.ipoed
            return 0 if game.num_certs(player) >= game.cert_limit(player)
            return 0 if player.companies.any? { |candidate| candidate == company || candidate.id == company.id }
            return 0 if concession_opening_cost(game, player, company).infinite?

            owned = player.companies.select { |candidate| candidate.meta&.[](:type) == :concession && !candidate.closed? }
            return 0 if owned.empty?
            return 0 if owned.size >= profile[:max_concession_plan_size]
            pressure = train_pressure_concession_motive?(game, player, corporation)
            bailout = second_corporation_bailout_motive?(game, player)
            return 0 if second_concession_saturated?(game, player) && !bailout && !pressure

            with_plan = best_concession_opening_plan_score(
              game,
              player,
              [company],
              required: [company],
              available_cash: player.cash - bid_price,
            )
            without_plan = best_concession_opening_plan_score(game, player, [])
            delta = with_plan - without_plan
            delta += profile[:extra_concession_bailout_bonus] if second_corporation_bailout_motive?(game, player)
            delta += TRAIN_PRESSURE_CONCESSION_BONUS if pressure
            return 0 if delta < profile[:extra_concession_min_delta]

            [concession_value(game, player, company), (delta / profile[:extra_concession_plan_divisor].to_f).round].min
          end

          def concession_price_enforcement_value(game, _player, company)
            return 0 unless game.corporation_by_id(company.sym)

            CONCESSION_PRICE_ENFORCEMENT_VALUE
          end

          def second_corporation_bailout_motive?(game, player)
            game.corporations.any? do |corporation|
              next false unless corporation.owner == player && corporation.ipoed

              weak_stock_corporation?(game, corporation) ||
                (permanent_train_near?(game) && !owns_permanent_train?(corporation)) ||
                (corporation.trains.empty? && corporation.cash < game.depot.min_depot_price)
            end
          end

          def private_value(game, player, company)
            value = eventual_private_corporations(game, player, company)
              .map { |corporation| private_value_for_corporation(game, corporation, company) }
              .max.to_i
            return value if value.positive?

            private_price_enforcement_value(company)
          end

          def eventual_private_corporations(game, player, company)
            game.corporations.select do |corporation|
              next false if corporation == game.ic
              next false unless corporation_controlled_by_player?(game, corporation, player)

              eventually_private_fits_corporation?(game, corporation, company)
            end
          end

          def corporation_controlled_by_player?(game, corporation, player)
            return true if corporation.owner == player

            concession = game.company_by_id(corporation.id)
            concession&.owner == player
          end

          def eventually_private_fits_corporation?(game, corporation, company)
            private_class = company.meta[:class]
            assigned_classes = game.used_private_classes(corporation)
            !assigned_classes.include?(private_class)
          end

          def private_useful_to_player?(game, player, company)
            return false unless eventual_private_corporations(game, player, company).any?

            private_class = company.meta[:class]
            private_class_slots(game, player, private_class) > player_private_class_count(player, private_class)
          end

          def private_class_slots(game, player, private_class)
            game.corporations.count do |corporation|
              next false if corporation == game.ic
              next false unless corporation_controlled_by_player?(game, corporation, player)

              eventually_private_fits_corporation?(game, corporation, company_for_private_class(private_class))
            end
          end

          def player_private_class_count(player, private_class)
            player.companies.count do |company|
              company.meta&.[](:type) == :private && company.meta[:class] == private_class
            end
          end

          def company_for_private_class(private_class)
            Struct.new(:meta).new({ class: private_class })
          end

          def private_price_enforcement_value(company)
            base = private_base_value(company)
            (base * profile[:private_price_enforcement_percent] / 100.0).floor
          end

          def private_fits_corporation?(game, corporation, company)
            private_class = company.meta[:class]
            assigned_classes = game.used_private_classes(corporation)
            return false if assigned_classes.include?(private_class)

            corporation.total_shares == 10 || private_class == :B
          end

          def private_auction_reserve(game, player)
            return 0 unless player

            share_reserve = next_share_purchase_price(game, player)
            concession_reserve = player.companies
              .select { |company| company.meta[:type] == :concession }
              .map { |company| concession_opening_cost(game, player, company) }
              .reject(&:infinite?)
              .min
            [share_reserve, concession_reserve, 0].compact.max
          end

          def next_share_purchase_price(game, player)
            shares = (game.corporations.flat_map(&:shares) + game.share_pool.shares).uniq
            shares.filter_map do |share|
              corporation = share.corporation
              next unless corporation.ipoed && financially_healthy_corporation?(game, corporation)
              next if share.owner == player || share.owner&.player?

              bundle = share.to_bundle
              next unless share.buyable && share_holding_limit_ok?(game, player, bundle)

              bundle.price
            end.min
          end

          def private_value_for_corporation(game, corporation, company)
            private_base_value(company) + private_context_bonus(game, corporation, company)
          end

          def private_context_bonus(game, corporation, company)
            base = private_base_value(company)
            case company.id
            when 'GTL'
              return -base unless corporation.tokens.any? { |token| !token.used }

              chicago_private_bonus(game)
            when 'TS'
              return -15 if owns_permanent_train?(corporation)

              permanent = cheapest_available_permanent_train(game)
              return 0 unless permanent || permanent_train_near?(game)

              train_price = permanent&.fetch(:price) || game.depot.min_depot_price
              discount = (train_price * 0.25).floor
              timing = train_timing_private_bonus(game, corporation, train_price, discount)
              package = [late_engine_private_package_bonus(game, corporation), 30].min
              target = [discount + timing + package, 150].min
              [target - base, 0].max
            when 'RD'
              return -25 if owns_permanent_train?(corporation)
              return 0 unless cheapest_available_permanent_train(game) || permanent_train_near?(game)

              return RUSH_DELIVERY_IMMEDIATE_PERMANENT_BONUS if rush_delivery_immediate_permanent_target?(game, corporation)

              corporation.trains.empty? ? 80 : 60
            when 'SP'
              return 0 unless private_share_issue_available?(corporation)

              price = corporation.share_price&.price.to_i
              target = price >= 100 ? price : price / 2
              target = [target, share_premium_train_timing_value(game, corporation, price)].max
              [target - base, 0].max
            when 'PO'
              return -base if owns_permanent_train?(corporation)
              return 70 if corporation.trains.any?(&:rusts_on) && (phase_number(game) >= 4 || permanent_train_near?(game))

              permanent_train_near?(game) ? 35 : 0
            when 'RE'
              train_bonus = [corporation.trains.size, 2].min * 10
              permanent_bonus = owns_permanent_train?(corporation) ? 15 : 0
              train_bonus + permanent_bonus
            when 'ICC'
              icc_connection_bonus(game, corporation)
            when 'USML'
              0
            when 'USY'
              return -base unless corporation.tokens.any? { |token| !token.used }

              corporation.ipoed ? 35 : 15
            when 'AT'
              0
            when 'CIB'
              central_il_boom_bonus(game)
            when 'CVCC'
              cvcc_fit_bonus(game, corporation)
            when 'EC'
              0
            when 'EM'
              0
            when 'ISBC'
              isbc_fit_bonus(game, corporation)
            when 'FWC'
              fwc_fit_bonus(game, corporation)
            else
              0
            end
          end

          def private_base_value(company)
            PRIVATE_VALUES.fetch(company.id, profile[:private_values].fetch(company.meta[:class], 0))
          end

          def chicago_private_bonus(game)
            case game.hex_by_id(game.class::CHICAGO_HEX.first).tile.color
            when :brown, :gray
              -35
            when :green
              10
            else
              25
            end
          end

          def private_share_issue_available?(corporation)
            return false unless corporation.share_price

            corporation.num_treasury_shares.positive? ||
              corporation.num_ipo_shares.positive? ||
              corporation.num_ipo_reserved_shares.positive?
          end

          def share_premium_useful_now?(game, corporation)
            return false unless private_share_issue_available?(corporation)
            return true if corporation.trains.empty? && corporation.cash < game.depot.min_depot_price
            return false if owns_permanent_train?(corporation)

            target = share_premium_train_target(game, corporation)
            return false unless target

            price = corporation.share_price&.price.to_i
            return false unless price.positive?

            share_premium_train_timing_value(game, corporation, price, target: target).positive?
          end

          def share_premium_train_timing_value(game, corporation, price, target: nil)
            return 0 if owns_permanent_train?(corporation)

            target ||= share_premium_train_target(game, corporation)
            return 0 unless target

            return price if corporation.cash < target[:price] && corporation.cash + (price * 2) >= target[:price]
            return 0 if price < SHARE_PREMIUM_LATE_MIN_PRICE

            corporation.cash + price < target[:price] + SHARE_PREMIUM_PERMANENT_BUFFER ? price : 0
          end

          def share_premium_train_target(game, corporation)
            permanent_train_options(game, corporation).min_by { |option| option[:price] } ||
              cheapest_available_permanent_train(game)
          end

          def rush_delivery_immediate_permanent_target?(game, corporation)
            return false unless corporation.trains.any?

            permanent_train_options(game, corporation).any? { |option| option[:price] <= corporation.cash }
          end

          def central_il_boom_bonus(game)
            return 100 if game.phase.tiles.include?(:gray)
            return 45 if phase_number(game) >= 6 || permanent_train_near?(game)
            return 25 if phase_number(game) >= 5

            0
          end

          def cvcc_fit_bonus(game, corporation)
            center_distance = nearest_home_distance(game, corporation, CENTRAL_TOWN_HEXES)
            nearby_towns = (game.class::TOWN_HEXES - game.class::GALENA_HEX - game.class::JACKSONVILLE_HEX)
              .count { |hex_id| home_distance(game, corporation, hex_id) <= 3 }
            center_bonus = if center_distance <= 1
                             25
                           elsif center_distance <= 2
                             20
                           elsif center_distance <= 3
                             10
                           else
                             0
                           end

            center_bonus + [nearby_towns * 3, 15].min
          end

          def isbc_fit_bonus(game, corporation)
            bonus = if WATER_PRIVATE_FIT_CORPORATIONS.include?(corporation.id)
                      40
                    elsif nearest_home_distance(game, corporation, WATER_PRIVATE_HEXES) <= 2
                      15
                    else
                      0
                    end
            bonus -= 25 if phase_number(game) >= 5

            [bonus, 0].max
          end

          def fwc_fit_bonus(game, corporation)
            galena_open = game.hex_by_id(game.class::GALENA_HEX.first).tile.color == :white
            return GALENA_PRIVATE_FIT_CORPORATIONS.include?(corporation.id) ? 35 : 10 if galena_open

            GALENA_PRIVATE_FIT_CORPORATIONS.include?(corporation.id) ? 15 : 5
          end

          def nearest_home_distance(game, corporation, hex_ids)
            hex_ids.map { |hex_id| home_distance(game, corporation, hex_id) }.min || 99
          end

          def home_distance(game, corporation, hex_id)
            home = game.hex_by_id(Array(corporation.coordinates).first)
            target = game.hex_by_id(hex_id)
            return 99 unless home && target

            home.distance(target)
          end

          def phase_number(game)
            name = game.phase.name.to_s
            return 99 if name == 'D'

            name[/\d+/].to_i
          end

          def icc_connection_bonus(game, corporation)
            return 0 unless corporation.ipoed

            groups = connected_route_groups(game, corporation)
            return 65 if endpoint_pair_groups(game, corporation).positive?

            partial_pairs = 0
            partial_pairs += 1 if groups.one? { |group| %w[East West].include?(group) }
            partial_pairs += 1 if groups.one? { |group| %w[North South].include?(group) }

            partial_pairs.positive? ? 35 : 10
          end

          def train_timing_private_bonus(_game, corporation, train_price, discount)
            return 0 if owns_permanent_train?(corporation)

            cash = corporation.cash
            discounted_price = train_price - discount
            issue_proceeds = corporation.share_price&.price.to_i
            return 70 if cash < discounted_price && cash + issue_proceeds >= discounted_price
            return 50 if cash < train_price && cash + discount >= train_price
            return 35 if corporation.trains.empty?

            0
          end

          def late_engine_private_package_bonus(game, corporation)
            return 0 unless corporation&.ipoed

            bonus = 0
            bonus += 35 if corporation.id == 'IR'
            bonus += 30 if corporation.share_price&.price.to_i >= DELAYED_IR_MIN_PAR
            bonus += endpoint_pair_groups(game, corporation) * 25
            bonus += 25 if permanent_train_near?(game) && !owns_permanent_train?(corporation)
            bonus
          end

          def connected_route_groups(game, corporation)
            return [] unless corporation&.ipoed

            game.graph_for_entity(corporation).connected_nodes(corporation).keys.flat_map(&:groups).uniq
          end

          def endpoint_pair_groups(game, corporation)
            groups = connected_route_groups(game, corporation)
            pairs = 0
            pairs += 1 if groups.include?('East') && groups.include?('West')
            pairs += 1 if groups.include?('North') && groups.include?('South')
            pairs
          end

          def stock_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless actions.include?('par')

            intended = intended_launch_corporation(game, step, entity)
            owned_plan = owned_concession_opening_plan(game, entity) unless intended
            planned_corporations = owned_plan&.filter_map { |company| game.corporation_by_id(company.sym) }
            corporation = intended ||
              planned_corporations&.find { |candidate| game.can_par?(candidate, entity) } ||
              random_best_by(game, entity.companies
                .select { |company| company.meta[:type] == :concession }
                .filter_map { |company| game.corporation_by_id(company.sym) }
                .select { |candidate| game.can_par?(candidate, entity) }) do |candidate|
                  concession_value(game, entity, game.company_by_id(candidate.id))
                end
            return unless corporation

            share_price = launch_share_price(
              game,
              step,
              entity,
              corporation,
              preserve_intent: !intended.nil? || planned_corporations&.size.to_i > 1,
              planned_corporations: planned_corporations,
            )
            return unless share_price

            Decision.new(
              action: Engine::Action::Par.new(
                entity,
                corporation: corporation,
                share_price: share_price,
              ),
              reason: "Starts #{corporation.name} at par #{share_price.price}",
            )
          end

          def owned_concession_opening_plan(game, player)
            owned = player.companies.select { |company| company.meta[:type] == :concession && !company.closed? }
            return if owned.empty?

            best_concession_opening_plan(game, player, [], available_cash: player.cash)
          end

          def concession_launch_intent_stock_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('par')

            corporation = intended_launch_corporation(game, step, entity)
            return unless corporation

            share_price = launch_share_price(game, step, entity, corporation, preserve_intent: true)
            return unless share_price

            Decision.new(
              action: Engine::Action::Par.new(
                entity,
                corporation: corporation,
                share_price: share_price,
              ),
              reason: "Follows its concession plan by starting #{corporation.name} at par #{share_price.price}",
            )
          end

          def launch_share_price(game, step, player, corporation, preserve_intent:, planned_corporations: nil)
            par_prices = bot_par_prices(step.get_par_prices(player, corporation), corporation)
              .select { |price| launch_can_fund_train?(game, player, corporation, price.price) }
            if preserve_intent
              preserving_plan = if planned_corporations
                                  par_prices.select do |price|
                                    launch_par_preserves_follow_through?(
                                      game,
                                      step,
                                      player,
                                      corporation,
                                      price.price,
                                      planned_corporations,
                                    )
                                  end
                                else
                                  par_prices.select do |price|
                                    concession_intent_par_preserves_follow_through?(
                                      game,
                                      step,
                                      player,
                                      corporation,
                                      price.price,
                                    )
                                  end
                                end
              par_prices = preserving_plan unless preserving_plan.empty?

              expensive_defense_prices = par_prices.select do |price|
                concession_intent_expensive_defense_met?(game, player, corporation, price.price)
              end
              par_prices = expensive_defense_prices unless expensive_defense_prices.empty?
            end
            protected_par_prices = par_prices.select do |price|
              launch_cash_requirement_met?(game, player, corporation, price.price, player.cash, protect_presidency: true)
            end
            if protected_par_prices.empty?
              return if second_corporation_launch_score(game, player, corporation).positive?
            else
              par_prices = protected_par_prices
            end
            preserving_existing_presidencies = par_prices.select do |price|
              launch_preserves_existing_presidency_defense?(game, player, corporation, price.price)
            end
            par_prices = preserving_existing_presidencies unless preserving_existing_presidencies.empty?
            share_price = par_prices.max_by do |price|
              launch_par_score(game, player, corporation, price)
            end
            return unless share_price
            return if delayed_launch_preferred?(game, player, corporation, share_price.price)

            share_price
          end

          def intended_launch_corporation(game, step, player)
            intent = @concession_launch_intents[player.id]
            return unless intent
            return clear_concession_launch_intent(player) if intent[:turn] != game.turn

            owned_ids = player.companies
              .select { |company| company.meta[:type] == :concession && !company.closed? }
              .map(&:sym)
            planned_ids = intent[:corporations] & owned_ids
            return clear_concession_launch_intent(player) if planned_ids.empty?

            planned_ids.filter_map { |id| game.corporation_by_id(id) }.find do |corporation|
              next false unless game.can_par?(corporation, player)

              bot_par_prices(step.get_par_prices(player, corporation), corporation).any? do |price|
                launch_can_fund_train?(game, player, corporation, price.price) &&
                  !delayed_launch_preferred?(game, player, corporation, price.price)
              end
            end
          end

          def concession_intent_expensive_defense_met?(game, player, corporation, par)
            intent = @concession_launch_intents[player.id]
            return false unless intent&.dig(:defense) == :expensive_first_concession

            required = expensive_first_concession_launch_cash_required_at_par(corporation, par)
            required <= player.cash &&
              launch_can_fund_train?(game, player, corporation, par) &&
              !delayed_launch_preferred?(game, player, corporation, par)
          end

          def concession_intent_par_preserves_follow_through?(game, step, player, corporation, par)
            intent = @concession_launch_intents[player.id]
            return true unless intent

            remaining_corporations = intended_remaining_launch_corporations(game, step, player, corporation)
            launch_par_preserves_follow_through?(game, step, player, corporation, par, remaining_corporations)
          end

          def launch_par_preserves_follow_through?(game, step, player, corporation, par, remaining_corporations)
            remaining_corporations = remaining_corporations.reject do |candidate|
              candidate == corporation || !game.can_par?(candidate, player)
            end
            return true if remaining_corporations.empty?

            current_cost = launch_cash_required_for_position(game, player, corporation, par, protect_presidency: true)
            current_cost = concession_president_cash_required(corporation, par) if current_cost > player.cash
            remaining_cash = player.cash - current_cost
            return false if remaining_cash.negative?

            remaining_corporations.all? do |candidate|
              required = minimum_launch_cash_required(game, step, player, candidate, available_cash: remaining_cash)
              next false unless required

              remaining_cash -= required
              remaining_cash >= 0
            end
          end

          def intended_remaining_launch_corporations(game, step, player, current_corporation)
            intent = @concession_launch_intents[player.id]
            return [] unless intent

            owned_ids = player.companies
              .select { |company| company.meta[:type] == :concession && !company.closed? }
              .map(&:sym)
            (intent[:corporations] & owned_ids)
              .filter_map { |id| game.corporation_by_id(id) }
              .reject { |candidate| candidate == current_corporation || !game.can_par?(candidate, player) }
              .select do |candidate|
                bot_par_prices(step.get_par_prices(player, candidate), candidate).any? do |price|
                  launch_can_fund_train?(game, player, candidate, price.price, player_cash: player.cash) &&
                    !delayed_launch_preferred?(game, player, candidate, price.price)
                end
              end
          end

          def minimum_launch_cash_required(game, step, player, corporation, available_cash:)
            minimum_launch_cash_required_for_prices(
              game,
              player,
              corporation,
              bot_par_prices(step.get_par_prices(player, corporation), corporation),
              available_cash: available_cash,
              protect_presidency: true,
              allow_unprotected: false,
            )
          end

          def minimum_launch_cash_required_for_prices(game, player, corporation, prices, available_cash:,
                                                      protect_presidency:, allow_unprotected: true)
            pars = prices.map(&:price).sort
            protected = protect_presidency && pars.find do |par|
              launch_cash_requirement_met?(game, player, corporation, par, available_cash, protect_presidency: true)
            end
            par = protected
            if !par && allow_unprotected
              par = pars.find do |candidate|
                launch_cash_requirement_met?(game, player, corporation, candidate, available_cash,
                                             protect_presidency: false)
              end
            end
            return unless par

            launch_cash_required_for_position(game, player, corporation, par, protect_presidency: !protected.nil?)
          end

          def launch_cash_requirement_met?(game, player, corporation, par, available_cash, protect_presidency:)
            required = launch_cash_required_for_position(game, player, corporation, par,
                                                         protect_presidency: protect_presidency)
            required <= available_cash &&
              launch_can_fund_train?(game, player, corporation, par, player_cash: available_cash) &&
              !delayed_launch_preferred?(game, player, corporation, par)
          end

          def launch_preserves_existing_presidency_defense?(game, player, corporation, par)
            reserve = presidency_defense_cash_reserve(game, player)
            return true if reserve.zero?

            cost = launch_cash_required_for_position(game, player, corporation, par, protect_presidency: true)
            player.cash - cost >= reserve
          end

          def clear_concession_launch_intent(player)
            @concession_launch_intents.delete(player.id)
            nil
          end

          def strategic_stock_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('par')
            return if owned_concession_opening_plan(game, entity)&.size.to_i > 1

            target = strategic_concession_launch_target(game, step, entity)
            return unless target && target[:required_cash] <= entity.cash

            Decision.new(
              action: Engine::Action::Par.new(
                entity,
                corporation: target[:corporation],
                share_price: target[:share_price],
              ),
              reason: "Starts strategic corporation #{target[:corporation].name} at par #{target[:share_price].price}",
            )
          end

          def delayed_launch_preferred?(game, player, corporation, par)
            return false unless corporation.id == 'IR'
            return false unless player.companies.any? { |company| company.id == corporation.id }
            return false if par >= DELAYED_IR_MIN_PAR

            next_train = game.depot.upcoming.reject(&:reserved).first
            return false unless next_train
            return false if next_train.name.to_i < 4
            return false unless bot_par_prices(game.par_prices, corporation).any? { |price| price.price >= DELAYED_IR_MIN_PAR }

            true
          end

          def launch_par_score(game, player, corporation, price)
            [
              closure_reopen_launch_score(game, corporation),
              late_high_capitalization_par_score(game, player, corporation, price.price),
              train_pressure_launch_par_score(game, player, corporation, price.price),
              closure_launch_par_score(game, player, corporation, price.price),
              second_corporation_launch_score(game, player, corporation),
              profile[:par_values].fetch(price.price, 0),
              launch_takeover_safety_score(game, player, corporation, price.price),
              launch_treasury_score(game, player, corporation, price.price),
              launch_liquidity_score(game, player, corporation, price.price),
              price.price,
            ]
          end

          def closure_launch_par_score(game, player, corporation, par)
            score = closure_source_candidate_score(game, corporation, player: player)
            return 0 unless score.positive?

            affordability = launch_liquidity_score(game, player, corporation, par)
            low_par_bonus = [150 - par, 0].max * CLOSURE_LOW_PAR_BONUS / 110
            score + affordability + low_par_bonus
          end

          def launch_treasury_score(game, player, corporation, par)
            launch_projected_treasury(game, player, corporation, par) / LAUNCH_TREASURY_SCORE_DIVISOR
          end

          def launch_projected_treasury(game, player, corporation, par)
            president_share_count = corporation.presidents_percent / corporation.share_percent
            player_cash = player.cash - (president_share_count * par)
            return -Float::INFINITY if player_cash.negative?

            immediate_shares = launch_affordable_president_extra_shares(game, player, corporation, par, player_cash)
            treasury = corporation.cash + ((president_share_count + immediate_shares) * par)
            treasury -= launch_token_cost(game, corporation)
            treasury += launch_expected_issue_cash(corporation, par)
            treasury
          end

          def launch_affordable_president_extra_shares(game, player, corporation, par, player_cash)
            available_shares = corporation.total_shares - (corporation.presidents_percent / corporation.share_percent)
            available_shares -= 1 if corporation.total_shares == 10
            ownership_room = (PRESIDENT_MAX_OWNERSHIP_PERCENT - corporation.presidents_percent) / corporation.share_percent
            cert_room = game.cert_limit(player) - game.num_certs(player) - 1
            cash_room = player_cash / par

            [available_shares, ownership_room, cert_room, cash_room].min.clamp(0, available_shares)
          end

          def launch_takeover_safety_score(game, player, corporation, par)
            return 0 if corporation.total_shares <= 2

            units = launch_projected_president_units(game, player, corporation, par)
            return -LAUNCH_TAKEOVER_EXPOSURE_PENALTY unless units.positive?

            unless launch_presidency_protection_needed?(game, player, corporation, par)
              return units * LAUNCH_TAKEOVER_UNIT_BONUS
            end

            buy_depth = takeover_buy_depth(corporation, units)
            score = units * LAUNCH_TAKEOVER_UNIT_BONUS
            if buy_depth >= LAUNCH_TAKEOVER_LOCK_BUY_DEPTH
              score += LAUNCH_TAKEOVER_LOCK_BONUS
            else
              score -= LAUNCH_TAKEOVER_EXPOSURE_PENALTY
            end
            score
          end

          def launch_projected_president_units(game, player, corporation, par)
            president_units = corporation.presidents_percent / corporation.share_percent
            player_cash = player.cash - (president_units * par)
            return 0 if player_cash.negative?

            president_units + launch_affordable_president_extra_shares(game, player, corporation, par, player_cash)
          end

          def takeover_buy_depth(corporation, president_units, rival_units = 0)
            presidency_units = corporation.presidents_percent / corporation.share_percent
            [presidency_units, president_units + 1].max - rival_units
          end

          def launch_cash_required_for_position(game, player, corporation, par, protect_presidency:)
            protect = protect_presidency && launch_presidency_protection_needed?(game, player, corporation, par)
            launch_cash_required(corporation, par, protect_presidency: protect)
          end

          def launch_presidency_protection_needed?(game, player, corporation, par)
            return false if corporation.total_shares <= 2

            president_units = corporation.presidents_percent / corporation.share_percent
            rival_takeover_cash_threat?(game, player, corporation, president_units, par)
          end

          def rival_takeover_cash_threat?(game, player, corporation, president_units, price)
            game.players.reject { |candidate| candidate == player }.any? do |rival|
              rival_takeover_capacity_units(game, rival, corporation, price) > president_units
            end
          end

          def rival_takeover_capacity_units(game, rival, corporation, price)
            current_units = rival.shares_of(corporation).sum(&:percent) / corporation.share_percent
            available_units = available_takeover_share_units(game, corporation)
            affordable_units = price.positive? ? (rival.cash / price) : 0

            current_units + [available_units, affordable_units].min
          end

          def available_takeover_share_units(game, corporation)
            shares = corporation.shares + game.share_pool.shares_of(corporation)
            shares.uniq.sum do |share|
              next 0 if share.president
              next 0 unless [corporation, game.share_pool].include?(share.owner)
              next 0 if corporation.ipoed && share.owner == corporation && !share.buyable

              share.percent / corporation.share_percent
            end
          end

          def presidency_defense_cash_reserve(game, player)
            game.corporations.filter_map do |corporation|
              next unless corporation.owner == player
              next unless corporation.ipoed && corporation.total_shares > 2
              next unless presidency_worth_protecting?(game, corporation)

              current_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
              next unless rival_takeover_cash_threat?(
                game,
                player,
                corporation,
                current_units,
                corporation.share_price&.price.to_i,
              )

              available_presidency_share_bundle(game, player, corporation)&.price
            end.max.to_i
          end

          def launch_cash_required(corporation, par, protect_presidency:)
            units = corporation.presidents_percent / corporation.share_percent
            units = [units, launch_presidency_target_units(corporation, par)].max if protect_presidency
            units * par
          end

          def launch_presidency_target_units(corporation, par)
            case corporation.total_shares
            when 10
              par <= 40 ? 4 : 3
            when 5
              3
            else
              corporation.presidents_percent / corporation.share_percent
            end
          end

          def launch_expected_issue_cash(corporation, par)
            return 0 unless corporation.total_shares >= 5

            par
          end

          def launch_liquidity_score(game, player, corporation, par)
            president_share_count = corporation.presidents_percent / corporation.share_percent
            remaining_cash = player.cash - (president_share_count * par)
            return 0 if remaining_cash < par

            extra_shares = launch_affordable_president_extra_shares(game, player, corporation, par, remaining_cash)

            extra_shares * 100
          end

          def second_corporation_launch_score(game, player, corporation)
            return 0 unless player
            return 0 unless game.corporations.any? { |candidate| candidate.owner == player && candidate.ipoed }
            return 0 unless corporation_controlled_by_player?(game, corporation, player)
            return 0 if corporation.ipoed

            bonus = SECOND_CORPORATION_LAUNCH_BONUS
            bonus += 40 if corporation.total_shares <= 5
            bonus += 40 if %w[NC IR].include?(corporation.id)
            bonus += 30 if corporation.id == 'G&CU'
            bonus += 30 if permanent_train_near?(game)
            bonus
          end

          def late_high_capitalization_par_score(game, player, corporation, par)
            return 0 unless late_high_capitalization_launch?(game, player, corporation)
            return 0 if par < LATE_HIGH_CAPITALIZATION_MIN_PAR

            bonus = LATE_HIGH_CAPITALIZATION_BONUS
            bonus += 180 if par >= 150
            bonus += 60 if cheapest_available_permanent_train(game)
            bonus
          end

          def train_pressure_concession_value(game, player, corporation)
            return 0 unless train_pressure_concession_motive?(game, player, corporation)

            TRAIN_PRESSURE_CONCESSION_BONUS
          end

          def train_pressure_launch_par_score(game, player, corporation, par)
            return 0 unless train_pressure_launch_plan?(game, player, corporation, par)

            TRAIN_PRESSURE_LAUNCH_BONUS + (par >= 150 ? TRAIN_PRESSURE_HIGH_PAR_BONUS : 0)
          end

          def train_pressure_concession_motive?(game, player, corporation)
            train_pressure_launch_candidate?(game, player, corporation) &&
              train_pressure_launch_reachable?(game, player, corporation)
          end

          def train_pressure_launch_candidate?(game, player, corporation)
            return false unless player
            return false unless corporation
            return false if corporation.ipoed
            return false unless corporation.total_shares >= 5
            return false unless train_pressure_window?(game)
            return false unless game.corporations.any? { |candidate| candidate.owner == player && candidate.ipoed }

            concession = game.company_by_id(corporation.id)
            corporation_controlled_by_player?(game, corporation, player) || !concession&.owner&.player?
          end

          def train_pressure_launch_reachable?(game, player, corporation, available_cash: player.cash)
            !train_pressure_launch_par(game, player, corporation, available_cash: available_cash).nil?
          end

          def train_pressure_launch_plan?(game, player, corporation, par, available_cash: player.cash)
            return false unless train_pressure_launch_candidate?(game, player, corporation)
            return false if par < LATE_HIGH_CAPITALIZATION_MIN_PAR

            cash_capacity = available_cash + train_pressure_launch_sale_capacity(game, player, corporation)
            share_price = bot_par_prices(game.par_prices, corporation).find { |price| price.price == par }
            return false unless share_price

            plan = late_train_launch_capitalization_plan(
              game,
              corporation,
              share_price,
              available_cash: cash_capacity,
            )
            return false unless plan

            TRAIN_PRESSURE_TARGET_TRAIN_NAMES.include?(plan[:projected_train][:name])
          end

          def train_pressure_launch_par(game, player, corporation, available_cash: player.cash)
            bot_par_prices(game.par_prices, corporation)
              .select { |price| price.price >= LATE_HIGH_CAPITALIZATION_MIN_PAR }
              .sort_by(&:price)
              .reverse
              .find { |price| train_pressure_launch_plan?(game, player, corporation, price.price, available_cash: available_cash) }
          end

          def train_pressure_launch_cash_required(game, player, corporation)
            par = train_pressure_launch_par(game, player, corporation)
            return unless par

            late_train_launch_capitalization_plan(game, corporation, par, available_cash: Float::INFINITY)&.dig(:required_cash)
          end

          def train_pressure_capitalization_candidate?(game, player, corporation)
            return false unless player
            return false unless corporation&.ipoed
            return false unless corporation.owner == player
            return false unless corporation.total_shares >= 5
            return false if owns_permanent_train?(corporation)
            return false unless train_pressure_window?(game)

            return true if corporation.share_price&.price.to_i >= LATE_HIGH_CAPITALIZATION_MIN_PAR
            return false unless corporation.total_shares == 5

            !conversion_train_pressure_target(
              game,
              corporation,
              projected_post_conversion_funding(game, corporation, 10),
            ).nil?
          end

          def train_pressure_window?(game)
            return false unless phase_4a_or_later?(game)
            return false if cheapest_available_permanent_train(game)

            !train_pressure_target_train(game).nil?
          end

          def train_pressure_target_train(game)
            game.depot.upcoming.reject(&:reserved).flat_map do |train|
              train.variants.values.map do |variant|
                { name: variant[:name], price: variant[:price] || train.price }
              end
            end.find { |option| TRAIN_PRESSURE_TARGET_TRAIN_NAMES.include?(option[:name]) }
          end

          def train_pressure_launch_sale_capacity(game, player, target_corporation)
            return 0 unless player

            train_pressure_launch_sale_bundles(game, player, target_corporation).sum { |_corporation, bundle| bundle.price }
          end

          def train_pressure_launch_sale_bundles(game, player, target_corporation)
            game.corporations.reject { |corporation| corporation == target_corporation }.flat_map do |corporation|
              game.bundles_for_corporation(player, corporation).map { |bundle| [corporation, bundle] }
            end.select do |corporation, bundle|
              !bundle.presidents_share &&
                !healthy_presidency_takeover_exposure_after_sale?(game, player, bundle) &&
                !presidency_retention_sale_blocked?(game, player, bundle) &&
                !market_close_protection_sale_blocked?(game, bundle) &&
                !high_upside_engine_sale_blocked?(game, player, bundle) &&
                !endgame_premium_stock_sale_blocked?(
                  game,
                  bundle,
                  purpose: :launch,
                  target_corporation: target_corporation,
                ) &&
                !weak_stock_corporation?(game, corporation)
            end
          end

          def late_high_capitalization_launch?(game, player, corporation)
            return false unless player
            return false unless phase_4a_or_later?(game) || permanent_train_near?(game)

            existing_operator = game.corporations.any? { |candidate| candidate.owner == player && candidate.ipoed }
            founder_pivot = investor_founder_pivot?(game, player)
            return false unless existing_operator || founder_pivot

            unless corporation_controlled_by_player?(game, corporation, player)
              concession = game.company_by_id(corporation.id)
              return false unless founder_pivot && (!concession&.owner || concession.owner == player)
            end
            return false if corporation.ipoed
            return false unless corporation.total_shares >= 5

            true
          end

          def investor_founder_launch_par(game, player, corporation, available_cash:)
            investor_founder_launch_plan(game, player, corporation, available_cash: available_cash)&.dig(:share_price)
          end

          def investor_founder_launch_plan(game, player, corporation, available_cash:)
            return unless corporation
            return unless investor_founder_pivot?(game, player)

            bot_par_prices(game.par_prices, corporation)
              .select { |price| price.price >= LATE_HIGH_CAPITALIZATION_MIN_PAR }
              .filter_map do |price|
                investor_founder_capitalization_plan(
                  game,
                  player,
                  corporation,
                  price,
                  available_cash: available_cash,
                )
              end
              .max_by do |plan|
                [
                  *launch_par_score(game, player, corporation, plan[:share_price]),
                  plan[:projected_train][:price],
                  plan[:personal_share_units],
                  -plan[:required_cash],
                ]
              end
          end

          def investor_founder_capitalization_plan(game, _player, corporation, share_price, available_cash:)
            late_train_launch_capitalization_plan(game, corporation, share_price, available_cash: available_cash)
          end

          def late_train_launch_capitalization_plan(game, corporation, share_price, available_cash:)
            return unless share_price.price >= LATE_HIGH_CAPITALIZATION_MIN_PAR

            projected_train = projected_investor_founder_train(game, corporation, share_price)
            return unless projected_train

            par = share_price.price
            president_share_units = corporation.presidents_percent / corporation.share_percent
            issue_proceeds = investor_founder_issue_proceeds(game, corporation, par)
            president_share_units.upto(INVESTOR_FOUNDER_MAX_SHARES) do |share_units|
              required_cash = share_units * par
              next if required_cash > available_cash

              token_cost = investor_founder_token_cost(game, corporation, projected_train, share_units)
              projected_treasury = corporation.cash + required_cash + issue_proceeds - token_cost
              next if projected_treasury < projected_train[:price]

              return {
                share_price: share_price,
                required_cash: required_cash,
                personal_share_units: share_units,
                issue_proceeds: issue_proceeds,
                token_cost: token_cost,
                projected_treasury: projected_treasury,
                projected_train: projected_train,
              }
            end

            nil
          end

          def investor_founder_concession_bonus(game, player, company)
            return 0 unless investor_founder_concession_candidate?(game, player, company)

            corporation = game.corporation_by_id(company.sym)
            sale_capacity = investor_founder_sale_capacity(game, player)
            plan = investor_founder_launch_plan(game, player, corporation, available_cash: player.cash + sale_capacity)
            return 0 unless plan

            margin = [plan[:projected_treasury] - plan[:projected_train][:price], 0].max
            margin_bonus = [margin / INVESTOR_FOUNDER_TREASURY_MARGIN_DIVISOR, INVESTOR_FOUNDER_TREASURY_MARGIN_CAP].min
            INVESTOR_FOUNDER_LAUNCH_BONUS +
              investor_founder_projected_train_bonus(plan[:projected_train]) +
              margin_bonus
          end

          def investor_founder_projected_train_bonus(projected_train)
            INVESTOR_FOUNDER_TRAIN_BONUSES.fetch(projected_train[:name], 0)
          end

          def investor_founder_issue_proceeds(game, corporation, par)
            return 0 if game.last_set
            return 0 unless corporation.total_shares >= 5

            par
          end

          def investor_founder_token_cost(game, corporation, projected_train, share_units)
            cost = launch_token_cost(game, corporation)
            return cost unless corporation.total_shares == 5

            converts = share_units > 3 || permanent_train_variant?(projected_train[:variant])
            converts ? cost + launch_token_unit_cost : cost
          end

          def projected_investor_founder_train(game, corporation, share_price)
            train_queue = game.depot.upcoming.reject(&:reserved).dup
            ahead_purchases = []

            projected_operating_corporations_ahead(game, corporation, share_price).each do |candidate|
              depot_train = train_queue.first
              break unless depot_train
              next unless projected_corporation_likely_to_buy_train?(game, candidate, depot_train, ahead_purchases)

              variant = projected_cheapest_train_variant(depot_train)
              ahead_purchases << {
                corporation: candidate.id,
                train: depot_train,
                name: variant[:name],
                price: variant[:price] || depot_train.price,
              }
              train_queue.shift
            end

            depot_train = train_queue.first
            return unless depot_train

            variant = projected_cheapest_train_variant(depot_train)
            {
              train: depot_train,
              variant: variant,
              name: variant[:name],
              price: variant[:price] || depot_train.price,
              ahead_purchases: ahead_purchases.map do |purchase|
                {
                  corporation: purchase[:corporation],
                  name: purchase[:name],
                  price: purchase[:price],
                }
              end,
            }
          end

          def projected_operating_corporations_ahead(game, corporation, share_price)
            target_key = projected_share_price_sort_order_key(share_price, corporation)
            game.corporations
              .select do |candidate|
                next false if candidate == corporation || candidate.closed? || !candidate.floated?

                candidate_key = candidate.sort_order_key
                candidate_key && (candidate_key <=> target_key)&.negative?
              end
              .sort
          end

          def projected_share_price_sort_order_key(share_price, corporation)
            coordinates = share_price.coordinates || [0, 0]
            [
              -share_price.price,
              -coordinates.last,
              coordinates.first,
              share_price.corporations.size,
              corporation.name,
            ]
          end

          def projected_corporation_likely_to_buy_train?(game, corporation, depot_train, ahead_purchases)
            remaining_trains = projected_remaining_trains_after_purchases(game, corporation, ahead_purchases)
            return true if remaining_trains.empty?

            depot_train.variants.values.any? do |variant|
              price = variant[:price] || depot_train.price
              projected_corporation_train_buying_cash(game, corporation, remaining_trains, variant) >= price &&
                projected_valid_train_mix?(game, corporation, remaining_trains, variant)
            end
          end

          def projected_remaining_trains_after_purchases(game, corporation, ahead_purchases)
            corporation.trains.reject do |train|
              ahead_purchases.any? { |purchase| game.rust?(train, purchase[:train]) }
            end
          end

          def projected_corporation_train_buying_cash(game, corporation, remaining_trains, variant)
            cash = corporation.cash
            return cash unless permanent_train_variant?(variant)
            return cash if remaining_trains.any? { |train| train.rusts_on.nil? && train.obsolete_on.nil? }

            cash += projected_last_route_revenue(corporation)
            issue = game.issuable_shares(corporation).first
            cash += issue.price if issue
            cash
          end

          def projected_last_route_revenue(corporation)
            history = corporation.operating_history.values.last
            return 0 unless history

            history.respond_to?(:revenue) ? history.revenue.to_i : history[:revenue].to_i
          end

          def projected_valid_train_mix?(game, corporation, remaining_trains, variant)
            limit = game.train_limit(corporation)
            return true if limit <= 1

            train_names = remaining_trains.map(&:name) + [variant[:name]]
            return true if train_names == %w[2 2] && two_run_network?(game, corporation)

            train_names.size < limit || train_names.uniq.size > 1
          end

          def projected_cheapest_train_variant(depot_train)
            depot_train.variants.values.min_by { |variant| variant[:price] || depot_train.price }
          end

          def investor_founder_sale_capacity(game, player, step: nil)
            investor_founder_sale_bundles(game, player, step: step).sum { |_corporation, bundle| bundle.price }
          end

          def investor_founder_sale_bundles(game, player, step: nil)
            game.corporations.filter_map do |corporation|
              bundle = game.bundles_for_corporation(player, corporation)
                .reject(&:presidents_share)
                .select do |candidate|
                  (!step || personal_stock_sale_allowed?(game, step, player, candidate)) &&
                    investor_founder_liquidation_allowed?(game, player, candidate)
                end
                .max_by(&:price)
              [corporation, bundle] if bundle
            end
          end

          def investor_founder_liquidation_allowed?(game, player, bundle)
            !healthy_presidency_takeover_exposure_after_sale?(game, player, bundle) &&
              !presidency_retention_sale_blocked?(game, player, bundle) &&
              !market_close_protection_sale_blocked?(game, bundle) &&
              !endgame_premium_stock_sale_blocked?(game, bundle, purpose: :launch, target_corporation: nil)
          end

          def phase_4a_or_later?(game)
            !%w[2 3].include?(game.phase.name)
          end

          def random_best_by(game, candidates)
            scored = candidates.map { |candidate| [yield(candidate), candidate] }
            best_score = scored.map(&:first).max
            tied = scored.select { |score, _candidate| score == best_score }.map(&:last)
            return tied.first if tied.size <= 1

            tied[game.rand % tied.size]
          end

          def share_purchase_decision(game, step, entity, actions)
            return unless share_purchase_step?(step)
            return unless actions.include?('buy_shares')
            return unless entity.player?

            if step.is_a?(G18IL::Step::PostConversionShares)
              corporation = step.corporation
              return if corporation.owner != entity && corporation.trains.empty?
            end

            bundle = purchasable_share_bundles(game, step, entity).max_by do |candidate|
              [
                post_formation_ic_priority(game, step, entity, candidate),
                ic_presidency_priority(game, entity, candidate),
                market_close_protection_priority(game, entity, candidate),
                presidency_takeover_priority(game, entity, candidate),
                closure_share_accumulation_priority(game, entity, candidate),
                train_pressure_capitalization_priority(game, entity, candidate),
                president_capitalization_priority(entity, candidate),
                c_ei_capital_priority(game, entity, candidate),
                presidency_protection_priority(game, entity, candidate),
                high_upside_engine_share_priority(game, entity, candidate),
                investor_portfolio_priority(game, entity, candidate),
                strong_own_engine_priority(game, entity, candidate),
                stock_purchase_score(game, entity, candidate),
                candidate.corporation.name,
              ]
            end
            return unless bundle

            post_conversion = step.is_a?(G18IL::Step::PostConversionShares)
            role = bundle.corporation.owner == entity ? 'president' : 'non-president'
            reason = if post_conversion
                       "The #{role} buys a post-conversion share of #{bundle.corporation.name}"
                     elsif presidency_free_investor_mode?(game, entity)
                       "Builds an investor portfolio with a share of #{bundle.corporation.name} for #{bundle.price} " \
                         "from #{share_source_name(game, bundle)}"
                     else
                       "Buys a share of #{bundle.corporation.name} for #{bundle.price} from " \
                         "#{share_source_name(game, bundle)}"
                     end

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: reason,
            )
          end

          def share_purchase_step?(step)
            step.is_a?(G18IL::Step::BaseBuySellParShares) ||
              step.is_a?(G18IL::Step::PostConversionShares)
          end

          def forced_stock_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player?
            return unless actions.include?('sell_shares')
            return if actions.include?('pass')

            bundles = game.corporations.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation)
            end
            bundle = bundles.select { |candidate| personal_stock_sale_allowed?(game, step, entity, candidate) }
              .min_by do |candidate|
                [candidate.presidents_share ? 1 : 0, candidate.percent, candidate.price, candidate.corporation.name]
              end
            return unless bundle

            Decision.new(
              action: Engine::Action::SellShares.new(entity, shares: bundle.shares, percent: bundle.percent),
              reason: "Sells #{bundle.percent}% of #{bundle.corporation.name} to satisfy ownership limits",
            )
          end

          def presidency_protection_purchase_decision(game, step, entity, actions)
            return unless share_purchase_step?(step)
            return unless entity.player? && actions.include?('buy_shares')

            corporation, bundle = threatened_presidency_purchase(game, entity)
            return unless bundle && bundle.price <= entity.cash
            return unless step.can_buy?(entity, bundle)

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "Buys a share of #{corporation.name} to retain its presidency",
            )
          end

          def presidency_funding_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('sell_shares')

            corporation, protection_bundle = threatened_presidency_purchase(game, entity)
            return unless protection_bundle && protection_bundle.price > entity.cash

            candidates = game.corporations.reject { |candidate| candidate == corporation }.flat_map do |candidate|
              game.bundles_for_corporation(entity, candidate).map { |bundle| [candidate, bundle] }
            end.select do |_candidate, bundle|
              funding_stock_sale_allowed?(
                game,
                step,
                entity,
                bundle,
                purpose: corporation == game.ic ? :ic : :presidency,
                target_corporation: corporation,
              ) &&
                entity.cash + bundle.price >= protection_bundle.price
            end
            sale_corporation, sale_bundle = candidates.min_by do |candidate, bundle|
              [
                bundle.presidents_share ? 1 : 0,
                bundle.num_shares,
                weak_stock_corporation?(game, candidate) ? 0 : 1,
                bundle.percent,
                candidate.name,
              ]
            end
            return unless sale_bundle

            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: sale_bundle.shares,
                percent: sale_bundle.percent,
              ),
              reason: "Sells #{sale_bundle.percent}% of #{sale_corporation.name} to fund presidency protection " \
                      "in #{corporation.name}",
            )
          end

          def threatened_presidency_purchase(game, player)
            game.corporations.sort_by(&:name).each do |corporation|
              next unless corporation.owner == player
              next unless presidency_worth_protecting?(game, corporation)

              player_percent = player.shares_of(corporation).sum(&:percent)
              tied = game.players.reject { |candidate| candidate == player }.any? do |candidate|
                candidate.shares_of(corporation).sum(&:percent) >= player_percent
              end
              next unless tied

              bundle = available_presidency_share_bundle(game, player, corporation)
              return [corporation, bundle] if bundle
            end

            nil
          end

          def presidency_lockdown_purchase_decision(game, step, entity, actions)
            return unless share_purchase_step?(step)
            return unless entity.player? && actions.include?('buy_shares')

            corporation, bundle = presidency_lockdown_purchase(game, step, entity)
            return unless bundle

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "Buys a share of #{corporation.name} to make its presidency harder to take over",
            )
          end

          def presidency_lockdown_purchase(game, step, player)
            game.corporations.sort_by(&:name).filter_map do |corporation|
              next unless corporation.owner == player
              next unless corporation.ipoed && corporation.total_shares > 2
              next unless presidency_worth_protecting?(game, corporation)
              next if step.respond_to?(:corporation) && step.corporation && step.corporation != corporation

              current_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
              rival_units = largest_rival_units(game, player, corporation)
              next if current_units < corporation.presidents_percent / corporation.share_percent
              next if rival_units < current_units
              next if takeover_buy_depth(corporation, current_units, rival_units) >= LAUNCH_TAKEOVER_LOCK_BUY_DEPTH

              bundle = available_presidency_share_bundle(game, player, corporation)
              next unless bundle && bundle.price <= player.cash && step.can_buy?(player, bundle)

              target_units = presidency_retention_target_units(game, player, corporation)
              next if current_units >= target_units

              [corporation, bundle]
            end.first
          end

          def available_presidency_share_bundle(game, player, corporation)
            shares = if corporation == game.ic
                       ic_share_candidates(game)
                     else
                       corporation.shares + game.share_pool.shares_of(corporation)
                     end
            shares.uniq.filter_map do |share|
              next if share.owner == player || share.owner&.player?

              corporate_ic = corporation == game.ic && share.owner&.corporation? &&
                share.owner&.president?(player)
              next unless share.buyable || corporate_ic

              bundle = share.to_bundle
              next unless share_holding_limit_ok?(game, player, bundle)

              bundle
            end.min_by(&:price)
          end

          def presidency_worth_protecting?(game, corporation)
            return true if ic_presidency_worth_protecting?(game, corporation)

            !weak_stock_corporation?(game, corporation)
          end

          def ic_presidency_worth_protecting?(game, corporation)
            return false unless corporation == game.ic
            return false unless corporation&.ipoed

            game.post_ic_formation_stock_round? ||
              ic_engine_dominant?(game) ||
              corporation.trains.any? ||
              corporation.share_price&.price.to_i >= game.class::IC_STARTING_PRICE
          end

          def presidency_retention_target_units(game, player, corporation)
            return corporation.presidents_percent / corporation.share_percent if corporation.total_shares <= 2

            base = launch_presidency_target_units(corporation, corporation.share_price&.price.to_i)
            rival_units = largest_rival_units(game, player, corporation)
            lock_target = LAUNCH_TAKEOVER_LOCK_BUY_DEPTH + rival_units - 1
            max_units = PRESIDENT_MAX_OWNERSHIP_PERCENT / corporation.share_percent

            [[base, lock_target].max, max_units].min
          end

          def largest_rival_units(game, player, corporation)
            game.players.reject { |candidate| candidate == player }
              .map { |candidate| candidate.shares_of(corporation).sum(&:percent) / corporation.share_percent }
              .max
              .to_i
          end

          def president_capitalization_purchase_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('buy_shares')

            bundle = purchasable_share_bundles(game, step, entity)
              .select { |candidate| president_capitalization_priority(entity, candidate).positive? }
              .min_by { |candidate| [candidate.corporation.total_shares, candidate.price, candidate.corporation.name] }
            return unless bundle

            remember_train_funding_intent(game, bundle.corporation, reason: :president_capitalization)
            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "The president buys a treasury share of trainless #{bundle.corporation.name} to capitalize it",
            )
          end

          def concession_launch_funding_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('sell_shares')

            target = strategic_concession_launch_target(game, step, entity)
            return unless target && target[:required_cash] > entity.cash

            sale_corporation, sale_bundle = concession_launch_sale_candidates(game, step, entity, target)
              .min_by do |corporation, bundle|
                [
                  bundle.num_shares,
                  weak_stock_corporation?(game, corporation) ? 0 : 1,
                  corporation.owner == entity ? 1 : 0,
                  bundle.percent,
                  corporation.name,
                ]
              end
            return unless sale_bundle

            reason = if target[:founder_pivot]
                       "Sells #{sale_bundle.percent}% of #{sale_corporation.name} to turn its investor portfolio " \
                         "into a #{target[:share_price].price}-par launch of #{target[:corporation].name}"
                     else
                       "Sells #{sale_bundle.percent}% of #{sale_corporation.name} to fund opening " \
                         "#{target[:corporation].name}"
                     end
            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: sale_bundle.shares,
                percent: sale_bundle.percent,
              ),
              reason: reason,
            )
          end

          def strategic_concession_launch_target(game, step, player)
            player.companies
              .select { |company| company.meta[:type] == :concession }
              .filter_map do |company|
                corporation = game.corporation_by_id(company.sym)
                next unless corporation && game.can_par?(corporation, player)

                founder_pivot = investor_founder_concession_candidate?(game, player, company)
                founder_capacity = player.cash + investor_founder_sale_capacity(game, player, step: step) if founder_pivot
                founder_plans = {}

                share_price = bot_par_prices(game.par_prices, corporation)
                  .select do |price|
                    if founder_pivot
                      plan = investor_founder_capitalization_plan(
                        game,
                        player,
                        corporation,
                        price,
                        available_cash: founder_capacity,
                      )
                      founder_plans[price] = plan if plan
                      next !plan.nil?
                    else
                      projected_cash = [
                        player.cash,
                        late_high_capitalization_cash_required(game, player, corporation, price.price),
                      ].max
                      launch_can_fund_train?(game, player, corporation, price.price, player_cash: projected_cash)
                    end
                  end
                  .max_by { |price| launch_par_score(game, player, corporation, price) }
                next unless share_price
                next if delayed_launch_preferred?(game, player, corporation, share_price.price)

                founder_plan = founder_plans[share_price]
                pressure = train_pressure_launch_plan?(game, player, corporation, share_price.price)
                score = concession_value(game, player, company) +
                  second_corporation_launch_score(game, player, corporation) +
                  (founder_pivot ? INVESTOR_FOUNDER_LAUNCH_BONUS : 0) +
                  (pressure ? TRAIN_PRESSURE_LAUNCH_BONUS : 0)
                next if score < CONCESSION_LAUNCH_FUNDING_THRESHOLD

                {
                  corporation: corporation,
                  share_price: share_price,
                  required_cash: founder_plan ? founder_plan[:required_cash] : concession_launch_cash_required(game, player, corporation, share_price.price),
                  score: score,
                  train_pressure: pressure,
                  founder_pivot: founder_pivot,
                  founder_plan: founder_plan,
                }
              end.max_by { |target| [target[:score], target[:share_price].price] }
          end

          def concession_launch_cash_required(game, player, corporation, par)
            [
              launch_cash_required_for_position(game, player, corporation, par, protect_presidency: true),
              late_high_capitalization_cash_required(game, player, corporation, par),
            ].max
          end

          def concession_president_cash_required(corporation, par)
            president_share_count = corporation.presidents_percent / corporation.share_percent
            president_share_count * par
          end

          def late_high_capitalization_cash_required(game, player, corporation, par)
            return 0 unless late_high_capitalization_launch?(game, player, corporation)
            return 0 if par < LATE_HIGH_CAPITALIZATION_MIN_PAR

            if investor_founder_pivot?(game, player)
              share_price = bot_par_prices(game.par_prices, corporation).find { |price| price.price == par }
              return Float::INFINITY unless share_price

              plan = investor_founder_capitalization_plan(
                game,
                player,
                corporation,
                share_price,
                available_cash: Float::INFINITY,
              )
              return plan ? plan[:required_cash] : Float::INFINITY
            end

            share_price = bot_par_prices(game.par_prices, corporation).find { |price| price.price == par }
            plan = late_train_launch_capitalization_plan(
              game,
              corporation,
              share_price,
              available_cash: Float::INFINITY,
            ) if share_price
            return plan[:required_cash] if plan && train_pressure_launch_candidate?(game, player, corporation)

            LATE_HIGH_CAPITALIZATION_TARGET_SHARES * par
          end

          def concession_launch_sale_candidates(game, step, player, target)
            shortfall = target[:required_cash] - player.cash
            game.corporations.reject { |corporation| corporation == target[:corporation] }.flat_map do |corporation|
              game.bundles_for_corporation(player, corporation).map { |bundle| [corporation, bundle] }
            end.select do |_corporation, bundle|
              sale_allowed = if target[:founder_pivot]
                               !bundle.presidents_share &&
                                 personal_stock_sale_allowed?(game, step, player, bundle) &&
                                 investor_founder_liquidation_allowed?(game, player, bundle)
                             else
                               !bundle.presidents_share &&
                                 funding_stock_sale_allowed?(
                                   game,
                                   step,
                                   player,
                                   bundle,
                                   purpose: :launch,
                                   target_corporation: target[:corporation],
                                 )
                             end
              sale_allowed &&
                (bundle.price >= shortfall || target[:train_pressure] || target[:founder_pivot])
            end
          end

          def market_close_protection_purchase_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('buy_shares')

            bundle = market_close_protection_bundles(game, step, entity).first
            return unless bundle

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "Buys a market share of #{bundle.corporation.name} before market shares can push it to closure",
            )
          end

          def market_close_protection_funding_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('sell_shares')

            targets = market_close_protection_bundles(
              game,
              step,
              entity,
              available_cash: Float::INFINITY,
              allow_sale_to_free_cert: true,
            )
              .select { |target| target.price > entity.cash }
            return if targets.empty?

            target, sale_corporation, sale_bundle = targets.flat_map do |target_bundle|
              game.corporations.reject { |corporation| corporation == target_bundle.corporation }.flat_map do |corporation|
                game.bundles_for_corporation(entity, corporation).map { |bundle| [target_bundle, corporation, bundle] }
              end
            end.select do |target_bundle, _corporation, bundle|
              !bundle.presidents_share &&
                funding_stock_sale_allowed?(
                  game,
                  step,
                  entity,
                  bundle,
                  purpose: :market_close_protection,
                  target_corporation: target_bundle.corporation,
                ) &&
                entity.cash + bundle.price >= target_bundle.price
            end.min_by do |target_bundle, corporation, bundle|
              [
                -market_close_protection_urgency(game, target_bundle.corporation),
                target_bundle.corporation.owner == entity ? 0 : 1,
                bundle.num_shares,
                weak_stock_corporation?(game, corporation) ? 0 : 1,
                bundle.percent,
                corporation.name,
              ]
            end
            return unless sale_bundle

            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: sale_bundle.shares,
                percent: sale_bundle.percent,
              ),
              reason: "Sells #{sale_bundle.percent}% of #{sale_corporation.name} to fund a market share of " \
                      "#{target.corporation.name} before it can close",
            )
          end

          def market_close_protection_bundles(game, step, player, available_cash: player.cash, allow_sale_to_free_cert: false)
            game.corporations
              .select { |corporation| market_close_protection_candidate?(game, corporation) }
              .flat_map { |corporation| game.share_pool.shares_of(corporation) }
              .uniq
              .filter_map do |share|
                next unless share.buyable

                bundle = share.to_bundle
                next unless market_close_protection_gain_allowed?(
                  game,
                  step,
                  player,
                  bundle,
                  available_cash,
                  allow_sale_to_free_cert,
                )

                bundle
              end.sort_by do |bundle|
                corporation = bundle.corporation
                [
                  -market_close_protection_urgency(game, corporation),
                  corporation.owner == player ? 0 : 1,
                  player.shares_of(corporation).any? ? 0 : 1,
                  -corporation.num_market_shares,
                  bundle.price,
                  corporation.name,
                ]
              end
          end

          def market_close_protection_gain_allowed?(game, step, player, bundle, available_cash, allow_sale_to_free_cert)
            corporation = bundle.corporation
            return false unless bundle.owner == game.share_pool
            return false unless bundle.buyable
            return false if bundle.price > available_cash
            return false if game.num_certs(player) >= game.cert_limit(player) && !allow_sale_to_free_cert
            return false unless share_holding_limit_ok?(game, player, bundle)

            round = step.instance_variable_get(:@round)
            return false if round&.players_sold&.[](player)&.[](corporation)
            return false if step.respond_to?(:bought?) && step.bought?

            true
          end

          def president_market_share_purchase_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('buy_shares')

            bundle = president_market_share_bundles(game, step, entity).find { |candidate| candidate.price <= entity.cash }
            return unless bundle

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "The president buys a market share of #{bundle.corporation.name} to keep it fully held",
            )
          end

          def president_market_share_funding_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('sell_shares')

            target = president_market_share_bundles(game, step, entity).first
            return unless target && target.price > entity.cash

            candidates = game.corporations.reject { |corporation| corporation == target.corporation }.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation).map { |bundle| [corporation, bundle] }
            end.select do |_corporation, bundle|
              !bundle.presidents_share &&
                funding_stock_sale_allowed?(
                  game,
                  step,
                  entity,
                  bundle,
                  purpose: :president_market_share,
                  target_corporation: target.corporation,
                ) &&
                entity.cash + bundle.price >= target.price
            end
            sale_corporation, sale_bundle = candidates.min_by do |corporation, bundle|
              [
                bundle.num_shares,
                weak_stock_corporation?(game, corporation) ? 0 : 1,
                corporation.owner == entity ? 1 : 0,
                bundle.percent,
                corporation.name,
              ]
            end
            return unless sale_bundle

            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: sale_bundle.shares,
                percent: sale_bundle.percent,
              ),
              reason: "Sells #{sale_bundle.percent}% of #{sale_corporation.name} to fund a market share of " \
                      "#{target.corporation.name}",
            )
          end

          def president_market_share_bundles(game, step, player)
            game.corporations.select { |corporation| corporation.owner == player }
              .select { |corporation| president_market_share_target?(game, corporation) }
              .flat_map { |corporation| game.share_pool.shares_of(corporation) }
              .uniq
              .filter_map do |share|
                next unless share.buyable

                bundle = share.to_bundle
                next unless president_market_share_gain_allowed?(game, step, player, bundle)

                bundle
              end.sort_by do |bundle|
                corporation = bundle.corporation
                [
                  owns_permanent_train?(corporation) ? 0 : 1,
                  financially_healthy_corporation?(game, corporation) ? 0 : 1,
                  -corporation.share_price.price,
                  corporation.name,
                ]
              end
          end

          def president_market_share_target?(game, corporation)
            corporation.ipoed && presidency_worth_protecting?(game, corporation) &&
              corporation.num_market_shares.positive?
          end

          def president_market_share_gain_allowed?(game, step, player, bundle)
            corporation = bundle.corporation
            return false if game.num_certs(player) >= game.cert_limit(player)
            return false unless bundle.owner == game.share_pool
            return false unless bundle.buyable

            round = step.instance_variable_get(:@round)
            return false if round.players_sold[player]&.[](corporation)
            return false if step.bought?

            true
          end

          def ic_share_purchase_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('buy_shares')

            bundle = prioritized_ic_share_bundles(game, entity).find do |candidate|
              candidate.price <= entity.cash && step.can_buy?(entity, candidate)
            end
            return unless bundle

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "Buys an IC share from #{share_source_name(game, bundle)} to pursue the IC presidency",
            )
          end

          def ic_share_funding_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('sell_shares')

            ic_bundle = prioritized_ic_share_bundles(game, entity).first
            return unless ic_bundle && ic_bundle.price > entity.cash

            candidates = game.corporations.reject { |corporation| corporation == game.ic || corporation.owner == entity }
              .flat_map do |corporation|
                           game.bundles_for_corporation(entity, corporation).map { |bundle| [corporation, bundle] }
            end.select do |_corporation, bundle|
              !bundle.presidents_share &&
                funding_stock_sale_allowed?(
                  game,
                  step,
                  entity,
                  bundle,
                  purpose: :ic,
                  target_corporation: game.ic,
                ) &&
                entity.cash + bundle.price >= ic_bundle.price
            end
            sale_corporation, sale_bundle = candidates.min_by do |corporation, bundle|
              [
                bundle.num_shares,
                weak_stock_corporation?(game, corporation) ? 0 : 1,
                bundle.percent,
                corporation.name,
              ]
            end
            return unless sale_bundle

            remember_ic_share_intent(game, entity, ic_bundle)
            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: sale_bundle.shares,
                percent: sale_bundle.percent,
              ),
              reason: "Sells #{sale_bundle.percent}% of #{sale_corporation.name} to fund an IC share purchase " \
                      'without risking another presidency',
            )
          end

          def prioritized_ic_share_bundles(game, player)
            corporation = game.ic
            return [] unless corporation&.ipoed

            ic_share_candidates(game).filter_map do |share|
              owner = share.owner
              next if owner == player || owner&.player? || owner == corporation

              corporate_share = owner&.corporation? && owner&.president?(player)
              market_share = owner == game.share_pool
              next unless market_share || corporate_share
              next unless share.buyable || corporate_share

              bundle = share.to_bundle
              next unless share_holding_limit_ok?(game, player, bundle)

              [bundle, market_share ? 0 : 1, owner&.name.to_s]
            end.sort_by { |bundle, source_priority, owner_name| [source_priority, bundle.price, owner_name] }
              .map(&:first)
          end

          def ic_share_candidates(game)
            (game.ic.shares + game.share_pool.shares_of(game.ic) + corporate_ic_shares(game)).uniq
          end

          def dump_risk_stock_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player?
            return unless actions.include?('sell_shares')

            corporation, bundle = dump_risk_stock_sale_candidate(game, step, entity)
            return unless bundle

            Decision.new(
              action: Engine::Action::SellShares.new(entity, shares: bundle.shares, percent: bundle.percent),
              reason: "Sells #{bundle.percent}% of #{corporation.name} to avoid receiving an unhealthy presidency dump",
            )
          end

          def dump_risk_stock_sale_candidate(game, step, player)
            game.corporations.filter_map do |corporation|
              next if corporation.owner == player
              next unless weak_stock_corporation?(game, corporation)
              next unless presidency_dump_exposure?(game, step, player, corporation)

              holding = player.shares_of(corporation).sum(&:percent)
              next if holding <= corporation.share_percent

              bundle = game.bundles_for_corporation(player, corporation)
                .select { |candidate| holding - candidate.percent <= corporation.share_percent }
                .select { |candidate| discretionary_stock_sale_allowed?(game, step, player, candidate) }
                .max_by do |candidate|
                  remaining = holding - candidate.percent
                  [remaining, -candidate.percent]
                end
              next unless bundle

              [corporation, bundle]
            end.max_by do |corporation, bundle|
              [
                player.shares_of(corporation).sum(&:percent),
                bundle.price,
                corporation.share_price&.price.to_i,
                corporation.name,
              ]
            end
          end

          def presidency_dump_exposure?(game, step, player, corporation)
            president = corporation.owner
            return false unless president&.player?
            return false if president == player

            player_holding = player.shares_of(corporation).sum(&:percent)
            return false if player_holding <= corporation.share_percent

            president_holding = president.shares_of(corporation).sum(&:percent)
            return false if president_holding <= player_holding

            game.bundles_for_corporation(president, corporation).any? do |bundle|
              step.can_sell?(president, bundle) && president_holding - bundle.percent < player_holding
            end
          end

          def voluntary_stock_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player?
            return unless actions.include?('sell_shares')

            game.corporations.sort_by(&:name).each do |corporation|
              next unless weak_stock_corporation?(game, corporation)

              share_percent = corporation.share_percent
              holding = entity.shares_of(corporation).sum(&:percent)
              next if holding <= share_percent

              president = corporation.owner == entity
              if president
                successor = game.players.reject { |player| player == entity }.find do |player|
                  player.shares_of(corporation).sum(&:percent) >= corporation.presidents_percent
                end
                next unless successor
              end

              bundles = game.bundles_for_corporation(entity, corporation)
                .select { |bundle| holding - bundle.percent <= share_percent }
                .select { |bundle| discretionary_stock_sale_allowed?(game, step, entity, bundle) }
              bundle = bundles.max_by do |candidate|
                remaining = holding - candidate.percent
                [remaining, -candidate.percent]
              end
              next unless bundle
              next if !president && !replacement_share_available?(game, entity, corporation, bundle.price)

              role = president ? 'president' : 'non-president'
              return Decision.new(
                action: Engine::Action::SellShares.new(
                  entity,
                  shares: bundle.shares,
                  percent: bundle.percent,
                ),
                reason: "The #{role} sells down to at most one share of operationally weak #{corporation.name}",
              )
            end

            nil
          end

          def closure_stock_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player?
            return unless actions.include?('sell_shares')

            corporation = game.corporations.select { |candidate| candidate.owner == entity }
              .select { |candidate| closure_sell_down_candidate?(game, candidate) }
              .max_by { |candidate| closure_plan_score(game, candidate) }
            return unless corporation

            holding = entity.shares_of(corporation).sum(&:percent)
            return if holding <= corporation.presidents_percent

            bundle = game.bundles_for_corporation(entity, corporation)
              .reject(&:presidents_share)
              .select { |candidate| holding - candidate.percent >= corporation.presidents_percent }
              .select { |candidate| discretionary_stock_sale_allowed?(game, step, entity, candidate) }
              .max_by { |candidate| [candidate.percent, candidate.price] }
            return unless bundle

            remember_closure_intent(game, corporation, reason: :stock_sale)
            Decision.new(
              action: Engine::Action::SellShares.new(entity, shares: bundle.shares, percent: bundle.percent),
              reason: "Sells #{bundle.percent}% of closure candidate #{corporation.name} down toward its presidency",
            )
          end

          def closure_sell_down_candidate?(game, corporation)
            return false unless closure_plan_score(game, corporation) >= CLOSURE_STOCK_SALE_THRESHOLD
            return false unless corporation.num_market_shares.positive? || corporation.trains.empty?

            stripped = corporation.trains.empty? ||
              corporation.trains.none? { |train| train.rusts_on.nil? && train.obsolete_on.nil? }
            stripped && corporation.share_price&.price.to_i <= 80
          end

          def distressed_stock_corporation?(game, corporation)
            corporation.ipoed && corporation.operated? && corporation.trains.empty? &&
              corporation.cash < game.depot.min_depot_price
          end

          def weak_stock_corporation?(game, corporation)
            distressed_stock_corporation?(game, corporation) || imminent_train_rust_risk?(game, corporation)
          end

          def market_close_protection_candidate?(game, corporation, additional_market_shares: 0)
            return false unless corporation&.ipoed
            return false if corporation == game.ic
            return false if game.closed_corporations.include?(corporation)
            return false unless corporation.share_price
            return false if remembered_closure_intent?(game, corporation)
            return false if weak_stock_corporation?(game, corporation)

            market_shares = corporation.num_market_shares + additional_market_shares
            return false unless market_shares.positive?
            return false unless market_close_viable_corporation?(game, corporation)

            projected_market_share_close_index(game, corporation, market_shares) <= MARKET_CLOSE_PROTECTION_BUFFER_STEPS
          end

          def market_close_viable_corporation?(game, corporation)
            return true if corporation.trains.any?
            return true if financially_healthy_corporation?(game, corporation)

            corporation.cash >= game.depot.min_depot_price
          end

          def market_close_protection_urgency(game, corporation, additional_market_shares: 0)
            market_shares = corporation.num_market_shares + additional_market_shares
            projected_index = projected_market_share_close_index(game, corporation, market_shares)
            MARKET_CLOSE_PROTECTION_BUFFER_STEPS - projected_index
          end

          def projected_market_share_close_index(game, corporation, market_shares)
            stock_market_steps_to_close(game, corporation) - market_shares
          end

          def stock_market_steps_to_close(game, corporation)
            share_price = corporation.share_price
            return Float::INFINITY unless share_price

            row, column = share_price.coordinates
            close_column = game.stock_market.market[row]&.index { |price| price&.type == :close }
            return Float::INFINITY unless close_column

            column - close_column
          end

          def imminent_train_rust_risk?(game, corporation)
            return false unless corporation.ipoed && corporation.operated? && corporation.trains.any?

            next_train = game.depot.upcoming.reject(&:reserved).first
            return false unless next_train
            return false unless corporation.trains.all? { |train| game.rust?(train, next_train) }

            corporation.cash < projected_launch_train_price(game)
          end

          def replacement_share_available?(game, player, distressed_corporation, sale_proceeds)
            available_cash = player.cash + sale_proceeds
            share_purchase_sources(game).any? do |share|
              corporation = share.corporation
              next false if corporation == distressed_corporation || !corporation.ipoed
              next false if share.owner == player || share.owner&.player?

              corporate_ic = corporation == game.ic && share.owner&.corporation? &&
                share.owner&.president?(player)
              next false unless share.buyable || corporate_ic

              bundle = share.to_bundle
              bundle.price <= available_cash && share_holding_limit_ok?(game, player, bundle)
            end
          end

          def share_holding_limit_ok?(game, player, bundle)
            return true if bundle.corporation == game.ic

            bundle.corporation.holding_ok?(player, bundle.common_percent)
          end

          def purchasable_share_bundles(game, step, player)
            conversion_reserve = if step.is_a?(G18IL::Step::BaseBuySellParShares)
                                   conversion_cash_reserve(game, player)
                                 else
                                   0
                                 end
            auction_reserve = if step.is_a?(G18IL::Step::BaseBuySellParShares)
                                ic_auction_cash_reserve(game, player)
                              else
                                0
                              end
            launch_reserve = if step.is_a?(G18IL::Step::BaseBuySellParShares)
                               concession_launch_cash_reserve(game, step, player)
                             else
                               0
                             end
            cash_reserve = [conversion_reserve, auction_reserve, launch_reserve].max
            share_purchase_sources(game).filter_map do |share|
              next unless share.corporation.ipoed

              corporate_ic = share.corporation == game.ic && share.owner&.corporation? &&
                share.owner&.president?(player)
              next unless share.buyable || corporate_ic

              bundle = share.to_bundle
              next if bundle.price > player.cash
              next if player.cash - bundle.price < cash_reserve
              next unless investor_purchase_preserves_non_presidency?(game, player, bundle)
              next unless step.can_buy?(player, bundle)

              bundle
            end
          end

          def investor_purchase_preserves_non_presidency?(game, player, bundle)
            return true unless presidency_free_investor?(game, player)
            return false if weak_stock_corporation?(game, bundle.corporation)

            president = bundle.corporation.owner
            return true unless president&.player?
            return false if president == player

            projected_percent = player.shares_of(bundle.corporation).sum(&:percent) + bundle.percent
            president_percent = president.shares_of(bundle.corporation).sum(&:percent)
            projected_percent <= president_percent
          end

          def share_purchase_sources(game)
            (game.corporations.flat_map(&:shares) + game.share_pool.shares + corporate_ic_shares(game)).uniq
          end

          def corporate_ic_shares(game)
            game.corporations.flat_map(&:corporate_shares).select { |share| share.corporation == game.ic }
          end

          def concession_launch_cash_reserve(game, step, player)
            target = strategic_concession_launch_target(game, step, player)
            return 0 unless target
            if president_capitalization_share_available?(game, step, player) &&
                !two_corporation_train_bank_follow_through?(game, player, target[:corporation])
              return 0
            end
            return 0 unless concession_launch_reachable_this_stock_round?(game, step, player, target)

            target[:required_cash]
          end

          def two_corporation_train_bank_follow_through?(game, player, target_corporation)
            return false unless target_corporation && corporation_controlled_by_player?(game, target_corporation, player)

            game.corporations.any? do |corporation|
              next false unless corporation != target_corporation
              next false unless corporation.owner == player && corporation.ipoed

              two_corporation_train_bank_pair?(corporation, target_corporation)
            end
          end

          def concession_launch_reachable_this_stock_round?(game, step, player, target)
            return true if target[:required_cash] <= player.cash

            if target[:founder_pivot]
              capacity = player.cash + investor_founder_sale_capacity(game, player, step: step)
              return capacity >= target[:required_cash]
            end

            concession_launch_sale_candidates(game, step, player, target).any?
          end

          def president_capitalization_share_available?(game, step, player)
            game.corporations.any? do |corporation|
              next false unless corporation.owner == player
              next false unless corporation.ipoed && corporation.trains.empty?

              corporation.shares.any? do |share|
                next false unless share.owner == corporation && share.buyable

                bundle = share.to_bundle
                bundle.price <= player.cash &&
                  president_capitalization_priority(player, bundle).positive? &&
                  step.can_buy?(player, bundle)
              end
            end
          end

          def closure_share_accumulation_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.owner == player
            return 0 unless closure_source_candidate_score(game, corporation, player: player).positive?
            return 0 if weak_stock_corporation?(game, corporation)

            current_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
            target_units = [6, corporation.total_shares * 60 / 100].min
            current_units < target_units ? CLOSURE_SHARE_ACCUMULATION_BONUS : 0
          end

          def train_pressure_capitalization_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.owner == player
            return 0 unless train_pressure_capitalization_candidate?(game, player, corporation)
            return 0 unless bundle.owner == corporation || bundle.owner == game.share_pool

            current_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
            return 0 if current_units >= TRAIN_PRESSURE_TARGET_SHARES

            priority = TRAIN_PRESSURE_SHARE_PRIORITY
            priority += 1 if bundle.owner == corporation
            priority += 1 if corporation.trains.empty?
            priority
          end

          def conversion_cash_reserve(game, player)
            game.corporations.select { |corporation| corporation.owner == player }.sum do |corporation|
              next 0 unless conversion_expected_next_or?(game, corporation)

              target_size = corporation.total_shares == 2 ? 5 : 10
              share_percent = target_size == 5 ? 20 : 10
              new_shares = target_size == 5 ? 3 : 5
              reserve_shares = target_size == 10 ? 1 : 0
              treasury_shares = corporation.shares.count { |share| share.owner == corporation }
              available = treasury_shares + new_shares - reserve_shares
              holding = projected_conversion_holdings(game, corporation, target_size).fetch(player, 0)
              ownership_room = (60 - holding) / share_percent
              cert_room = game.cert_limit(player) - game.num_certs(player)
              purchases = [available, ownership_room, cert_room].min.clamp(0, available)
              purchases * corporation.share_price.price
            end
          end

          def conversion_expected_next_or?(game, corporation)
            return false unless corporation.ipoed && [2, 5].include?(corporation.total_shares)

            permanent = cheapest_available_permanent_train(game)
            needs_permanent = permanent && !owns_permanent_train?(corporation)
            needs_train_capital = corporation.trains.empty? &&
              corporation.cash + corporation.share_price.price < game.depot.min_depot_price
            train_pressure = train_pressure_capitalization_candidate?(game, corporation.owner, corporation) &&
              train_pressure_target_train(game)
            needs_permanent || needs_train_capital || train_pressure ||
              profile[:conversion_values].fetch(corporation.total_shares, 0).positive?
          end

          def stock_purchase_score(game, player, bundle)
            score = bundle.corporation.owner == player ? profile[:stock_own_corporation_bonus] : 0
            score += profile[:stock_market_bonus] if bundle.owner == game.share_pool
            score += profile[:stock_treasury_bonus] if bundle.owner == bundle.corporation
            score += MARKET_CLOSE_PROTECTION_STOCK_BONUS if market_close_protection_bundle?(game, bundle)
            score += high_upside_engine_stock_bonus(game, player, bundle)
            score += idle_cash_share_bonus(game, player, bundle)
            score += two_share_denial_stock_bonus(game, player, bundle)
            score -= weak_permanent_route_share_penalty(game, player, bundle)
            score + (bundle.price * profile[:stock_price_weight])
          end

          def high_upside_engine_share_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless high_upside_engine?(game, corporation)

            priority = HIGH_UPSIDE_ENGINE_SHARE_PRIORITY
            priority += 1 if corporation.owner == player
            priority += 1 if player.shares_of(corporation).any?
            priority += 1 if bundle.owner == game.share_pool
            priority += 1 if corporation == game.ic && ic_engine_dominant?(game)
            priority
          end

          def investor_portfolio_priority(game, player, bundle)
            return 0 unless presidency_free_investor?(game, player)
            return 0 if weak_stock_corporation?(game, bundle.corporation)

            priority = INVESTOR_PORTFOLIO_PRIORITY
            priority += 2 if player.shares_of(bundle.corporation).empty?
            priority += 1 if financially_healthy_corporation?(game, bundle.corporation)
            priority += [high_upside_engine_score(game, bundle.corporation), 3].min
            priority
          end

          def high_upside_engine_stock_bonus(game, player, bundle)
            return 0 unless high_upside_engine?(game, bundle.corporation)

            bonus = HIGH_UPSIDE_ENGINE_STOCK_BONUS
            bonus += 120 if player.shares_of(bundle.corporation).any?
            bonus += 120 if bundle.corporation.owner == player
            bonus
          end

          def high_upside_engine?(game, corporation)
            return false unless corporation&.ipoed
            return false if game.closed_corporations.include?(corporation)
            return false if weak_stock_corporation?(game, corporation)
            return true if corporation == game.ic && ic_engine_dominant?(game)

            high_upside_engine_score(game, corporation) >= HIGH_UPSIDE_ENGINE_MIN_SCORE
          end

          def high_upside_engine_score(game, corporation)
            score = 0
            score += 2 if owns_permanent_train?(corporation)
            score += 2 if corporation.trains.size >= 2
            score += 1 if corporation.share_price&.price.to_i >= 100
            score += endpoint_pair_groups(game, corporation) * 2
            score += strategic_anchor_tokens(corporation).size
            score += 2 if connected_revenue_nodes(game, corporation).size >= 4
            score += 1 if %w[IR NC].include?(corporation.id)
            score
          end

          def market_close_protection_priority(game, player, bundle)
            return 0 unless market_close_protection_bundle?(game, bundle)

            priority = MARKET_CLOSE_PROTECTION_PRIORITY
            priority += 2 if bundle.corporation.owner == player
            priority += 1 if player.shares_of(bundle.corporation).any?
            priority += 1 if owns_permanent_train?(bundle.corporation)
            priority
          end

          def market_close_protection_bundle?(game, bundle)
            bundle.owner == game.share_pool && market_close_protection_candidate?(game, bundle.corporation)
          end

          def idle_cash_share_bonus(game, player, bundle)
            return 0 if game.num_certs(player) >= game.cert_limit(player)
            return 0 if player.cash < bundle.price * 2
            return 0 unless financially_healthy_corporation?(game, bundle.corporation)

            IDLE_CASH_SHARE_BONUS
          end

          def two_share_denial_stock_bonus(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless %w[IR NC].include?(corporation.id)
            return 0 if corporation.owner == player

            sibling = game.corporation_by_id(corporation.id == 'IR' ? 'NC' : 'IR')
            return 0 unless sibling

            if game.players.reject { |candidate| candidate == player }.any? do |candidate|
              candidate == corporation.owner && candidate == sibling.owner
            end
              TWO_SHARE_DENIAL_STOCK_BONUS
            else
              0
            end
          end

          def weak_permanent_route_share_penalty(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.owner == player
            return 0 unless owns_permanent_train?(corporation)
            return 0 if mature_permanent_route?(game, corporation)

            WEAK_PERMANENT_ROUTE_SHARE_PENALTY
          end

          def mature_permanent_route?(game, corporation)
            endpoint_pair_groups(game, corporation).positive? ||
              strategic_anchor_tokens(corporation).size >= 2 ||
              connected_revenue_nodes(game, corporation).size >= 4
          end

          def strong_own_engine_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.owner == player
            return 0 if weak_stock_corporation?(game, corporation)

            priority = 1
            priority += 1 if owns_permanent_train?(corporation)
            priority += 1 if endpoint_pair_groups(game, corporation).positive?
            priority += 1 if bundle.owner == game.share_pool
            priority
          end

          def c_ei_capital_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.id == 'C&EI'
            return 0 unless corporation.owner == player
            return 0 unless bundle.owner == corporation

            corporation.cash < c_ei_required_opening_capital(game, corporation) ? 1 : 0
          end

          def president_capitalization_priority(player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.owner == player
            return 0 unless corporation.trains.empty?
            return 0 unless bundle.owner == corporation

            target_units = launch_presidency_target_units(corporation, bundle.price)
            return 0 unless target_units.positive?

            current_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
            current_units < target_units ? 1 : 0
          end

          def post_formation_ic_priority(game, step, player, bundle)
            return 0 unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return 0 unless bundle.corporation == game.ic

            priority = game.post_ic_formation_stock_round? ? 2 : 0
            priority += IC_SHARE_INTENT_PRIORITY if remembered_ic_share_intent?(game, player, bundle)
            priority += 2 if ic_engine_dominant?(game)
            priority += 1 if bundle.owner == game.share_pool
            priority += 1 if bundle.owner&.corporation? && bundle.owner&.president?(player)
            priority
          end

          def ic_presidency_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation == game.ic
            return 0 unless ic_presidency_worth_protecting?(game, corporation)

            player_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
            player_percent = player.shares_of(corporation).sum(&:percent)
            bundle_units = bundle.percent / corporation.share_percent
            president = corporation.owner
            president_units = president&.player? ? president.shares_of(corporation).sum(&:percent) / corporation.share_percent : 0
            target_units = presidency_retention_target_units(game, player, corporation)

            if president == player
              return 0 if player_units >= target_units

              IC_PRESIDENCY_DEFENSE_PRIORITY
            elsif player_units + bundle_units > president_units &&
                player_percent + bundle.percent >= corporation.presidents_percent
              IC_PRESIDENCY_PURSUIT_PRIORITY + (ic_engine_dominant?(game) ? 1 : 0)
            elsif game.post_ic_formation_stock_round? && player.shares_of(corporation).any?
              1
            else
              0
            end
          end

          def ic_engine_dominant?(game)
            ic = game.ic
            return false unless ic&.ipoed

            ic.trains.any? && (owns_permanent_train?(ic) || endpoint_pair_groups(game, ic).positive? ||
              strategic_anchor_tokens(ic).size >= 2)
          end

          def presidency_protection_priority(game, player, bundle)
            corporation = bundle.corporation
            return 0 unless corporation.owner == player
            return 0 unless presidency_worth_protecting?(game, corporation)

            player_percent = player.shares_of(corporation).sum(&:percent)
            other_percent = game.players.reject { |candidate| candidate == player }
              .map { |candidate| candidate.shares_of(corporation).sum(&:percent) }
              .max.to_i
            other_percent >= player_percent ? 1 : 0
          end

          def presidency_takeover_priority(game, player, bundle)
            corporation = bundle.corporation
            president = corporation.owner
            return 0 unless president&.player?
            return 0 if president == player
            return 0 unless presidency_worth_protecting?(game, corporation)

            player_percent = player.shares_of(corporation).sum(&:percent)
            president_percent = president.shares_of(corporation).sum(&:percent)
            return 0 unless player_percent + bundle.percent >= corporation.presidents_percent
            return 0 unless player_percent + bundle.percent > president_percent

            priority = 4
            priority += 1 if owns_permanent_train?(corporation)
            priority += 1 if financially_healthy_corporation?(game, corporation)
            priority
          end

          def closure_source_candidate_score(game, corporation, player: corporation&.owner)
            return 0 unless profile[:closure_strategy_weight].positive?
            return 0 unless corporation
            return 0 if corporation == game.ic
            return 0 unless corporation.total_shares == 10
            return 0 if corporation.share_price&.price.to_i >= 120
            return 0 if closure_active_operator_protected?(game, corporation)

            score = 30
            score += 20 if corporation.id == 'C&EI'
            score += 20 if corporation.share_price&.price.to_i <= 80
            score += 15 if corporation.trains.any?(&:rusts_on)
            score += 15 if corporation.trains.size >= 2
            score += closure_reopen_package_value(game, corporation) / 3
            score += 20 if player && closure_support_corporations(game, player, except: corporation).any?
            score * profile[:closure_strategy_weight] / 100
          end

          def closure_active_operator_protected?(game, corporation)
            return false unless corporation.ipoed
            return false if corporation.trains.empty?
            return false if imminent_train_rust_risk?(game, corporation)
            return true if owns_permanent_train?(corporation)
            return false if corporation.trains.size < CLOSURE_ACTIVE_OPERATOR_MIN_TRAINS

            connected_revenue_nodes(game, corporation).size >= CLOSURE_ACTIVE_OPERATOR_MIN_REVENUE_NODES
          rescue StandardError
            false
          end

          def closure_plan_score(game, corporation)
            score = closure_source_candidate_score(game, corporation)
            return 0 unless score.positive?

            score += 20 if corporation.ipoed
            score += 20 if game.operated_this_round?(corporation)
            score += 20 if corporation.trains.empty?
            score += corporation.num_market_shares * 8
            score += [80 - corporation.share_price&.price.to_i, 0].max / 2
            score += closure_reopen_package_value(game, corporation) / 2
            score += CLOSURE_INTENT_SCORE_BONUS if remembered_closure_intent?(game, corporation)
            score
          end

          def closure_reopen_launch_score(game, corporation)
            return 0 unless game.closed_corporations.include?(corporation)

            closure_reopen_package_value(game, corporation)
          end

          def closure_reopen_package_value(game, corporation)
            return 0 unless corporation
            return 0 if corporation == game.ic

            cash_value = corporation.cash / CLOSURE_REOPEN_CASH_DIVISOR
            train_value = corporation.trains.sum(&:price) / CLOSURE_REOPEN_TRAIN_DIVISOR
            private_value = corporation.companies.sum do |company|
              next 0 unless company.meta&.[](:type) == :private

              private_value_for_corporation(game, corporation, company) / CLOSURE_REOPEN_PRIVATE_DIVISOR
            end
            closed_bonus = game.closed_corporations.include?(corporation) ? CLOSURE_REOPEN_CLOSED_BONUS : 0

            (cash_value + train_value + private_value + closed_bonus) * profile[:closure_strategy_weight] / 100
          end

          def closure_support_candidate?(corporation)
            return false unless corporation
            return false if corporation.total_shares == 10

            corporation.share_price.nil? || corporation.share_price.price <= 100
          end

          def closure_support_corporations(game, player, except: nil)
            game.corporations.select do |corporation|
              corporation != except &&
                corporation_controlled_by_player?(game, corporation, player) &&
                closure_support_candidate?(corporation)
            end
          end

          def ic_auction_cash_reserve(game, player)
            return 0 unless player
            return 0 unless ic_auction_approaching?(game)

            profile[:ic_auction_cash_reserve]
          end

          def ic_auction_approaching?(game)
            return false if game.last_set
            return game.ic.ipo_shares.any? if game.ic_formation_triggered?

            completed = game.instance_variable_get(:@ic_line_completed_hexes)&.size.to_i
            completed >= IC_LINE_AUCTION_RESERVE_HEXES
          end

          def financially_healthy_corporation?(game, corporation)
            return true if owns_permanent_train?(corporation)

            permanent_price = cheapest_available_permanent_train(game)&.dig(:price)
            permanent_price && corporation.cash >= permanent_price * HEALTHY_PERMANENT_FUNDING_RATIO
          end

          def share_source_name(game, bundle)
            return 'the corporation' if bundle.owner == bundle.corporation
            return 'the Market' if bundle.owner == game.share_pool

            bundle.owner.name
          end

          def share_issue_decision(game, step, entity, actions)
            return unless entity.corporation?
            return unless actions.include?('sell_shares')
            return if step.is_a?(G18IL::Step::BuyTrainBeforeRunRoute) && actions.include?('pass')

            bundle =
              case step
              when G18IL::Step::IssueShares
                step.issuable_shares(entity).first
              when G18IL::Step::BuyTrain
                game.emergency_issuable_bundles(entity).first
              end
            return unless bundle

            mandatory_shortfall = entity.trains.empty? && entity.cash < game.depot.min_depot_price
            closure_pressure = closure_issue_pressure?(game, entity)

            if step.is_a?(G18IL::Step::IssueShares)
              permanent = affordable_permanent_train_after_issue(game, entity, bundle.price)
              three_train = affordable_three_train_after_issue(game, entity, bundle.price)
              zero_three_city = affordable_zero_three_city_train_after_issue(game, entity, bundle.price)
              route_creation_funding = route_creation_funding_needed?(game, entity, bundle.price)
            end
            building_three_fund = step.is_a?(G18IL::Step::IssueShares) && !three_train &&
              three_train_fund_target(game, entity)
            return if entity.share_price.price <= 40 && !mandatory_shortfall && !route_creation_funding && !closure_pressure &&
              !building_three_fund

            building_permanent_fund = step.is_a?(G18IL::Step::IssueShares) && !owns_permanent_train?(entity) &&
              cheapest_available_permanent_train(game)
            funding_stl_permit = cbq_needs_stl_permit_issue?(game, entity, bundle.price)
            return unless mandatory_shortfall || permanent || three_train || building_three_fund || zero_three_city || building_permanent_fund ||
              funding_stl_permit || route_creation_funding || closure_pressure

            if permanent
              remember_train_funding_intent(game, entity, target: permanent, reason: :share_issue)
            elsif three_train
              remember_train_funding_intent(game, entity, target: three_train, reason: :share_issue)
            elsif building_three_fund
              remember_train_funding_intent(game, entity, target: building_three_fund, reason: :share_issue)
            elsif zero_three_city
              remember_train_funding_intent(game, entity, target: zero_three_city, reason: :share_issue)
            elsif building_permanent_fund
              remember_train_funding_intent(game, entity, reason: :share_issue)
            end
            remember_closure_intent(game, entity, reason: :share_issue) if closure_pressure

            purpose = if funding_stl_permit
                        'fund an immediately usable St. Louis permit'
                      elsif route_creation_funding
                        'fund route-forming track while preserving train money'
                      elsif closure_pressure
                        'pressure its share price toward closure'
                      elsif permanent
                        "fund the #{permanent[:name]} permanent train for #{permanent[:price]}"
                      elsif three_train
                        "fund the #{three_train[:name]} train before its 2-trains rust"
                      elsif building_three_fund
                        "build toward the #{building_three_fund[:name]} train before its 2-trains rust"
                      elsif zero_three_city
                        "fund the #{zero_three_city[:name]} train for its city network"
                      elsif building_permanent_fund
                        'build its permanent-train fund'
                      else
                        'fund a mandatory train'
                      end

            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: bundle.shares,
                share_price: bundle.share_price,
              ),
              reason: "Issues #{bundle.num_shares} share#{bundle.num_shares == 1 ? '' : 's'} to #{purpose}",
            )
          end

          def closure_issue_pressure?(game, corporation)
            return false unless closure_plan_score(game, corporation) >= CLOSURE_ISSUE_SCORE_THRESHOLD
            return false unless corporation.trains.empty? || corporation.num_market_shares.positive?
            return false if corporation == game.ic

            corporation.share_price&.price.to_i <= 60
          end

          def cbq_needs_stl_permit_issue?(game, entity, proceeds)
            return false unless entity.id == 'CBQ'
            return false if game.stl_permit?(entity) || !game.stl_permit_available?
            return false unless stl_reachable?(game, entity)

            permit_cost = game.class::STL_PERMIT_COST
            entity.cash < permit_cost && entity.cash + proceeds >= permit_cost
          end

          def new_token_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BuyNewTokens)
            return unless actions.include?('choose')

            choices = step.choices.keys.map(&:to_i)
            return if choices.empty?

            desired = token_purchase_target(game, entity, step.pending_type, step.pending_max)
            count = choices.select { |number| number <= desired }
              .reverse
              .find { |number| token_purchase_preserves_train_funds?(game, entity, step.price(number)) }
            count ||= choices.min

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: count.to_s),
              reason: "Buys #{count} new token#{count == 1 ? '' : 's'} without compromising train funding",
            )
          end

          def token_purchase_target(game, entity, pending_type, maximum)
            return choices_minimum_token_target(maximum) if maximum <= 1

            base = if pending_type == :start
                     starting_token_target(entity,
                                           maximum)
                   else
                     conversion_token_target(game, entity, maximum)
                   end
            strategic = strategic_token_demand(game, entity)
            [[base + strategic, maximum].min, choices_minimum_token_target(maximum)].max
          end

          def choices_minimum_token_target(maximum)
            maximum.positive? ? 1 : 0
          end

          def starting_token_target(entity, maximum)
            return [3, maximum].min if entity.total_shares == 10
            return [2, maximum].min if entity.total_shares == 5

            1
          end

          def conversion_token_target(game, entity, maximum)
            return 1 if maximum <= 1

            hash = "#{game.seed}:#{game.turn}:#{entity.id}".each_byte.reduce(5381) do |value, byte|
              ((value << 5) + value) ^ byte
            end
            1 + (hash % [maximum, 3].min)
          end

          def strategic_token_demand(game, entity)
            token_candidates = reachable_strategic_token_hexes(game, entity)
            token_candidates.sum do |hex|
              strategic_anchor_token_hex?(game, hex.id) ? STRATEGIC_TOKEN_PURCHASE_SCORE : 1
            end
          end

          def reachable_strategic_token_hexes(game, entity)
            return [] unless entity.corporation?

            reachable = game.token_graph_for_entity(entity).reachable_hexes(entity)
            game.hexes.select do |hex|
              next false unless premium_token_hex?(game, hex)
              next false if strategic_anchor_tokens(entity).any? { |token| token.hex == hex }

              reachable[hex]
            end
          end

          def token_purchase_preserves_train_funds?(game, entity, cost)
            cash_after = entity.cash - cost
            permanent = permanent_train_options(game, entity).map { |option| option[:price] }.min
            return cash_after >= permanent if permanent && entity.cash >= permanent
            return cash_after >= game.depot.min_depot_price if entity.trains.empty?

            true
          end

          def affordable_permanent_train_after_issue(game, entity, proceeds)
            return if entity.cash >= game.depot.max_depot_price
            return if entity.trains.size >= game.train_limit(entity)

            permanent_train_options(game, entity)
              .select { |option| entity.cash < option[:price] && entity.cash + proceeds >= option[:price] }
              .min_by { |option| option[:price] }
          end

          def affordable_zero_three_city_train_after_issue(game, entity, proceeds)
            return if entity.trains.size >= game.train_limit(entity)
            return unless strong_zero_three_city_network?(game, entity)

            zero_three_city_train_options(game, entity)
              .select { |option| entity.cash < option[:price] && entity.cash + proceeds >= option[:price] }
              .min_by { |option| option[:price] }
          end

          def affordable_three_train_after_issue(game, entity, proceeds)
            return unless needs_three_train_before_four?(game, entity)

            three_train_options(game, entity)
              .select { |option| entity.cash < option[:price] && entity.cash + proceeds >= option[:price] }
              .min_by { |option| option[:price] }
          end

          def permanent_train_options(game, entity)
            options = game.depot.depot_trains.flat_map do |train|
              train.variants.values.filter_map do |variant|
                next unless permanent_train_variant?(variant)
                next unless valid_train_mix_after_purchase?(game, entity, variant, nil)

                { name: variant[:name], price: variant[:price] || train.price }
              end
            end
            game.discountable_trains_for(entity).each do |exchange, depot_train, variant_name, price|
              variant = depot_train.variants.values.find { |candidate| candidate[:name] == variant_name }
              next unless variant && permanent_train_variant?(variant)
              next unless valid_train_mix_after_purchase?(game, entity, variant, exchange)

              options << { name: variant_name, price: price }
            end
            options
          end

          def permanent_train_options_after_scrap(game, entity, scrapped_train)
            options = game.depot.depot_trains.flat_map do |train|
              train.variants.values.filter_map do |variant|
                next unless permanent_train_variant?(variant)
                next unless valid_train_mix_after_purchase_after_scrap?(game, entity, variant, nil, scrapped_train)

                { name: variant[:name], price: variant[:price] || train.price }
              end
            end
            game.discountable_trains_for(entity).each do |exchange, depot_train, variant_name, price|
              variant = depot_train.variants.values.find { |candidate| candidate[:name] == variant_name }
              next unless variant && permanent_train_variant?(variant)
              next unless valid_train_mix_after_purchase_after_scrap?(game, entity, variant, exchange, scrapped_train)

              options << { name: variant_name, price: price }
            end
            options
          end

          def three_train_options(game, entity)
            options = game.depot.depot_trains.flat_map do |train|
              train.variants.values.filter_map do |variant|
                next unless three_train_variant?(variant)
                next unless valid_train_mix_after_purchase?(game, entity, variant, nil)

                { name: variant[:name], price: variant[:price] || train.price }
              end
            end
            game.discountable_trains_for(entity).each do |exchange, depot_train, variant_name, price|
              variant = depot_train.variants.values.find { |candidate| candidate[:name] == variant_name }
              next unless variant && three_train_variant?(variant)
              next unless valid_train_mix_after_purchase?(game, entity, variant, exchange)

              options << { name: variant_name, price: price }
            end
            options
          end

          def zero_three_city_train_options(game, entity)
            options = game.depot.depot_trains.flat_map do |train|
              train.variants.values.filter_map do |variant|
                next unless zero_three_city_train_variant?(variant)
                next unless valid_train_mix_after_purchase?(game, entity, variant, nil)

                { name: variant[:name], price: variant[:price] || train.price }
              end
            end
            game.discountable_trains_for(entity).each do |exchange, depot_train, variant_name, price|
              variant = depot_train.variants.values.find { |candidate| candidate[:name] == variant_name }
              next unless variant && zero_three_city_train_variant?(variant)
              next unless valid_train_mix_after_purchase?(game, entity, variant, exchange)

              options << { name: variant_name, price: price }
            end
            options
          end

          def cheapest_available_permanent_train(game)
            game.depot.depot_trains.flat_map do |train|
              train.variants.values.filter_map do |variant|
                next unless permanent_train_variant?(variant)

                { name: variant[:name], price: variant[:price] || train.price }
              end
            end.min_by { |option| option[:price] }
          end

          def permanent_train_variant?(variant)
            variant[:rusts_on].nil? && variant[:obsolete_on].nil?
          end

          def three_train_variant?(variant)
            variant[:name] == '3'
          end

          def zero_three_city_train_variant?(variant)
            variant[:name] == '0+3C'
          end

          def owns_permanent_train?(entity)
            entity.trains.any? { |train| train.rusts_on.nil? && train.obsolete_on.nil? }
          end

          def remember_train_funding_intent(game, corporation, reason:, target: nil)
            return unless corporation&.corporation?

            target ||= preferred_train_funding_target(game, corporation)
            return unless target

            @train_funding_intents[corporation.id] = {
              turn: game.turn,
              name: target[:name],
              price: target[:price],
              permanent: target.fetch(:permanent, false),
              zero_three_city: zero_three_city_train_name?(target[:name]),
              three_train: target[:name] == '3',
              reason: reason,
            }
          end

          def preferred_train_funding_target(game, entity)
            zero_three_city = zero_three_city_train_options(game, entity).min_by { |option| option[:price] }
            return zero_three_city.merge(permanent: true) if zero_three_city && !owns_permanent_train?(entity)

            three_train = three_train_options(game, entity).min_by { |option| option[:price] }
            return three_train if three_train && needs_three_train_before_four?(game, entity)

            permanent = permanent_train_options(game, entity).min_by { |option| option[:price] }
            return permanent.merge(permanent: true) if permanent && !owns_permanent_train?(entity)

            cheapest_available_permanent_train(game)&.merge(permanent: true)
          end

          def remembered_train_funding_intent(game, corporation)
            intent = @train_funding_intents[corporation.id]
            return unless intent
            return if game.turn - intent[:turn].to_i > 2
            return if intent[:permanent] && owns_permanent_train?(corporation)

            intent
          end

          def train_funding_intent_bonus(game, entity, variant)
            intent = remembered_train_funding_intent(game, entity)
            return 0 unless intent

            bonus = 0
            bonus += TRAIN_FUNDING_INTENT_MATCH_BONUS if intent[:name] == variant[:name]
            bonus += TRAIN_FUNDING_INTENT_PERMANENT_BONUS if intent[:permanent] && permanent_train_variant?(variant)
            bonus += TRAIN_FUNDING_INTENT_THREE_BONUS if intent[:three_train] && three_train_variant?(variant)
            if intent[:zero_three_city] && zero_three_city_train_variant?(variant)
              bonus += TRAIN_FUNDING_INTENT_ZERO_THREE_CITY_BONUS
            end
            bonus
          end

          def zero_three_city_train_name?(name)
            name == '0+3C'
          end

          def remember_closure_intent(game, corporation, reason:)
            return unless corporation&.corporation?
            return if corporation == game.ic

            @closure_intents[corporation.id] = {
              turn: game.turn,
              reason: reason,
            }
          end

          def remembered_closure_intent?(game, corporation)
            intent = @closure_intents[corporation.id]
            return false unless intent
            return false if corporation == game.ic
            return false if game.closed_corporations.include?(corporation)
            return false if closure_active_operator_protected?(game, corporation)
            return false if corporation.share_price&.price.to_i >= 100 && owns_permanent_train?(corporation)

            true
          end

          def remember_ic_share_intent(game, player, bundle)
            @ic_share_intents[player.id] = {
              turn: game.turn,
              price: bundle.price,
            }
          end

          def remembered_ic_share_intent?(game, player, bundle)
            intent = @ic_share_intents[player.id]
            return false unless intent
            return false if intent[:turn] != game.turn

            bundle.price <= intent[:price]
          end

          def personal_stock_sale_allowed?(_game, step, player, bundle)
            step.can_sell?(player, bundle)
          end

          def discretionary_stock_sale_allowed?(game, step, player, bundle, purpose: nil, target_corporation: nil)
            personal_stock_sale_allowed?(game, step, player, bundle) &&
              !healthy_presidency_takeover_exposure_after_sale?(game, player, bundle) &&
              !presidency_retention_sale_blocked?(game, player, bundle) &&
              !market_close_protection_sale_blocked?(game, bundle) &&
              !high_upside_engine_sale_blocked?(game, player, bundle) &&
              !endgame_premium_stock_sale_blocked?(game, bundle, purpose: purpose, target_corporation: target_corporation)
          end

          def funding_stock_sale_allowed?(game, step, player, bundle, purpose: nil, target_corporation: nil)
            discretionary_stock_sale_allowed?(
              game,
              step,
              player,
              bundle,
              purpose: purpose,
              target_corporation: target_corporation,
            )
          end

          def endgame_premium_stock_sale_blocked?(game, bundle, purpose:, target_corporation:)
            return false unless endgame_stock_sale_window?(game)
            return false if concrete_late_stock_sale_purpose?(game, purpose, target_corporation)
            return false unless premium_stock_sale_bundle?(game, bundle)

            true
          end

          def endgame_stock_sale_window?(game)
            game.last_set || game.last_set_pending || !!game.game_end_trigger
          end

          def concrete_late_stock_sale_purpose?(game, purpose, target_corporation)
            purpose == :train || purpose == :ic || target_corporation == game.ic
          end

          def premium_stock_sale_bundle?(game, bundle)
            corporation = bundle.corporation
            return false unless corporation&.ipoed
            return false if weak_stock_corporation?(game, corporation)
            return true if high_upside_engine?(game, corporation)

            corporation.share_price&.price.to_i >= ENDGAME_PREMIUM_SHARE_PRICE &&
              (owns_permanent_train?(corporation) || mature_permanent_route?(game, corporation))
          end

          def presidency_retention_sale_blocked?(game, seller, bundle)
            corporation = bundle.corporation
            return false unless corporation.owner == seller
            return false unless presidency_worth_protecting?(game, corporation)

            current_units = seller.shares_of(corporation).sum(&:percent).to_f / corporation.share_percent
            remaining_units = current_units - (bundle.percent.to_f / corporation.share_percent)
            floor_units = [presidency_retention_target_units(game, seller, corporation), current_units].min

            remaining_units < floor_units
          end

          def high_upside_engine_sale_blocked?(game, player, bundle)
            corporation = bundle.corporation
            return false unless high_upside_engine?(game, corporation)
            return false if remembered_closure_intent?(game, corporation)

            holding = player.shares_of(corporation).sum(&:percent)
            floor = corporation.owner == player ? corporation.presidents_percent : corporation.share_percent
            holding - bundle.percent < floor
          end

          def market_close_protection_sale_blocked?(game, bundle)
            market_close_protection_candidate?(
              game,
              bundle.corporation,
              additional_market_shares: market_close_sale_share_count(bundle),
            )
          end

          def market_close_sale_share_count(bundle)
            return bundle.num_shares if bundle.respond_to?(:num_shares)

            (bundle.percent.to_f / bundle.corporation.share_percent).ceil
          end

          def healthy_presidency_takeover_exposure_after_sale?(game, seller, bundle)
            corporation = bundle.corporation
            return false unless corporation.owner == seller
            return false unless presidency_worth_protecting?(game, corporation)

            remaining_percent = seller.shares_of(corporation).sum(&:percent) - bundle.percent
            return false if remaining_percent < corporation.presidents_percent

            share_percent = corporation.share_percent
            sale_price = bundle.price
            game.players.reject { |player| player == seller }.any? do |player|
              player_percent = player.shares_of(corporation).sum(&:percent)
              player.cash >= sale_price &&
                player_percent + share_percent >= corporation.presidents_percent &&
                player_percent + share_percent >= remaining_percent
            end
          end

          def emergency_share_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BuyTrain)
            return unless entity.player?
            return unless actions.include?('sell_shares')

            bundles = game.corporations.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation)
            end
            bundles.select! { |candidate| personal_stock_sale_allowed?(game, step, entity, candidate) }
            shortfall = [step.needed_cash(entity) - step.available_cash(entity), 0].max
            sufficient = bundles.select { |candidate| candidate.price >= shortfall }
            bundle = if sufficient.any?
                       sufficient.min_by do |candidate|
                         [
                           candidate.num_shares,
                           candidate.corporation.trains.empty? ? 0 : 1,
                           candidate.price - shortfall,
                           candidate.presidents_share ? 1 : 0,
                           candidate.corporation.name,
                         ]
                       end
                     else
                       bundles.select { |candidate| candidate.num_shares == 1 }
                         .max_by do |candidate|
                           [
                             candidate.price,
                             candidate.corporation.trains.empty? ? 1 : 0,
                             candidate.presidents_share ? 0 : 1,
                             candidate.corporation.name,
                           ]
                         end
                     end
            return unless bundle

            train_status = bundle.corporation.trains.empty? ? 'trainless ' : ''
            Decision.new(
              action: Engine::Action::SellShares.new(entity, shares: bundle.shares, percent: bundle.percent),
              reason: "Sells #{bundle.num_shares} share#{bundle.num_shares == 1 ? '' : 's'} of " \
                      "#{train_status}#{bundle.corporation.name} for #{bundle.price} toward the #{shortfall} shortfall",
            )
          end

          def corporate_share_sale_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::CorporateSellShares)
            return unless actions.include?('corporate_sell_shares')

            bundle = entity.corporate_shares.map(&:to_bundle)
              .select { |candidate| step.can_sell?(entity, candidate) }
              .min_by { |candidate| [candidate.price, candidate.corporation.name] }
            return unless bundle

            Decision.new(
              action: Engine::Action::CorporateSellShares.new(entity, shares: bundle.shares),
              reason: "Sells a corporate share of #{bundle.corporation.name} for emergency train funding",
            )
          end

          def home_token_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::HomeToken)
            return unless actions.include?('place_token')

            hex = game.hexes.find { |candidate| step.available_hex(entity, candidate) }
            city = hex&.tile&.cities&.first
            return unless city

            Decision.new(
              action: Engine::Action::PlaceToken.new(entity, city: city),
              reason: "Places the home token in #{hex.id}",
            )
          end

          def draft_decision(game, step, entity, actions)
            draft_step = step.is_a?(G18IL::Step::DraftPrivate) || step.is_a?(G18IL::Step::FullDraft)
            return unless draft_step
            return unless actions.include?('bid')

            company = Array(step.available).max_by { |candidate| auction_item_value(game, entity, candidate) }
            return unless company

            Decision.new(
              action: Engine::Action::Bid.new(entity, company: company, price: 0),
              reason: "Drafts the highest-valued available item, #{company.name}",
            )
          end

          def dividend_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Dividend)
            return unless actions.include?('dividend')

            dividend_options = step.dividend_options(entity)
            if frozen_sold_out?(game, entity) && dividend_options[:half]
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'half'),
                reason: 'Half pays while frozen and sold out to pay down its loan without giving up all dividends',
              )
            end

            permanent_withhold = dividend_train_purchase(game, step, entity, dividend_options, :withhold,
                                                         permanent: true)
            permanent_half = dividend_train_purchase(game, step, entity, dividend_options, :half, permanent: true)
            three_withhold = dividend_train_purchase(game, step, entity, dividend_options, :withhold,
                                                     train_name: '3', new_rank: true)
            three_half = dividend_train_purchase(game, step, entity, dividend_options, :half,
                                                 train_name: '3', new_rank: true)
            if three_withhold && !three_half && !needs_three_train_before_four?(game, entity)
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'withhold'),
                reason: "Withholds to afford the #{three_withhold[:name]} before its 2-trains rust",
              )
            end

            if permanent_withhold && !permanent_half
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'withhold'),
                reason: "Withholds to afford the #{permanent_withhold[:name]} permanent train",
              )
            end

            half_new_rank = dividend_train_purchase(game, step, entity, dividend_options, :half, new_rank: true)
            if three_half
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'half'),
                reason: "Half pays to afford the #{three_half[:name]} before its 2-trains rust",
              )
            elsif half_new_rank
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'half'),
                reason: "Half pays to afford a new train rank, #{half_new_rank[:name]}",
              )
            end

            if permanent_withhold
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'withhold'),
                reason: "Withholds to afford the #{permanent_withhold[:name]} permanent train",
              )
            end

            if closure_hot_run?(game, entity)
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'payout'),
                reason: "Pays out #{entity.name} while pursuing a closure plan",
              )
            end

            kind = step.dividend_types.max_by do |type|
              dividend_kind_score(game, step, entity, dividend_options, type)
            end
            Decision.new(
              action: Engine::Action::Dividend.new(entity, kind: kind.to_s),
              reason: "Chooses the highest-scored dividend option, #{kind} " \
                      "(score #{dividend_kind_score(game, step, entity, dividend_options, kind).round})",
            )
          end

          def dividend_train_purchase(game, step, entity, dividend_options, kind, permanent: false, new_rank: false,
                                      train_name: nil)
            return unless dividend_options[kind]
            return if dividend_option_market_closes_viable_corporation?(game, entity, dividend_options[kind])

            payout_cash = projected_cash_after_dividend(step, entity, dividend_options, :payout)
            dividend_cash = projected_cash_after_dividend(step, entity, dividend_options, kind)
            dividend_train_options(game, entity)
              .select { |option| !permanent || option[:permanent] }
              .select { |option| !new_rank || entity.trains.none? { |train| train.name == option[:name] } }
              .select { |option| !train_name || option[:name] == train_name }
              .select { |option| payout_cash < option[:price] && dividend_cash >= option[:price] }
              .min_by { |option| option[:price] }
          end

          def three_train_fund_target(game, entity)
            return unless needs_three_train_before_four?(game, entity)

            three_train_options(game, entity)
              .select { |option| entity.cash < option[:price] }
              .min_by { |option| option[:price] }
          end

          def projected_cash_after_dividend(step, entity, dividend_options, kind)
            option = dividend_options[kind]
            return entity.cash unless option

            entity.cash + option.fetch(:corporation, 0) + option.fetch(:divs_to_corporation, 0) +
              dividend_subsidy(step)
          end

          def dividend_kind_score(game, step, entity, dividend_options, kind)
            option = dividend_options[kind]
            return -Float::INFINITY unless option
            return -Float::INFINITY if dividend_option_market_closes_viable_corporation?(game, entity, option)

            treasury_cash = option.fetch(:corporation, 0) + option.fetch(:divs_to_corporation, 0) + dividend_subsidy(step)
            owner_cash = dividend_owner_cash(step, entity, option)
            market_value = dividend_market_value_delta(game, entity, option)
            sibling_transfer_order_bonus = early_sibling_train_transfer_order_bonus(game, entity, option)

            (treasury_cash * DIVIDEND_TREASURY_CASH_WEIGHT) +
              (owner_cash * DIVIDEND_OWNER_CASH_WEIGHT) +
              (market_value * DIVIDEND_MARKET_CAP_WEIGHT) +
              sibling_transfer_order_bonus +
              profile[:dividend_values].fetch(kind, 0)
          end

          def early_sibling_train_transfer_order_bonus(game, entity, option)
            supports = early_sibling_train_transfer_support_corporations(game, entity)
            return 0 if supports.empty?

            new_price = dividend_resulting_share_price(game, entity, option)&.price
            support_price = supports.filter_map { |corporation| corporation.share_price&.price }.max
            return 0 unless new_price && support_price

            new_price <= support_price ? EARLY_SIBLING_TRAIN_TRANSFER_ORDER_BONUS : 0
          end

          def early_sibling_train_transfer_support_corporations(game, buyer)
            return [] unless game
            return [] unless buyer&.corporation?
            return [] unless buyer.total_shares == 2
            return [] unless buyer.owner&.player?

            game.corporations.select do |seller|
              next false if seller == buyer || seller == game.ic
              next false unless seller.owner == buyer.owner && seller.ipoed
              next false unless two_corporation_train_bank_pair?(buyer, seller)
              next false unless seller.trains.size > 1

              seller.trains.any? do |train|
                train_name = train.respond_to?(:name) ? train.name : nil
                EARLY_SIBLING_TRAIN_TRANSFER_NAMES.include?(train_name) &&
                  early_sibling_train_transfer_window?(game, train_name) &&
                  !(train.respond_to?(:rusted) && train.rusted) &&
                  !(train.respond_to?(:obsolete) && train.obsolete)
              end
            end
          end

          def dividend_owner_cash(step, entity, option)
            owner = entity.owner
            return 0 unless owner&.player?

            per_share = option.fetch(:per_share, 0)
            return step.dividends_for_entity(entity, owner, per_share) if step.respond_to?(:dividends_for_entity)

            (owner.num_shares_of(entity, ceil: false) * per_share).ceil
          end

          def dividend_market_value_delta(game, entity, option)
            current = entity.share_price
            return 0 unless current

            new_price = dividend_resulting_share_price(game, entity, option)
            return 0 unless new_price

            (new_price.price - current.price) * entity.total_shares
          end

          def dividend_resulting_share_price(game, entity, option)
            directions = Array(option[:share_direction]).flat_map.with_index do |direction, index|
              Array.new(Array(option[:share_times])[index] || option[:share_times].to_i, direction)
            end
            return entity.share_price if directions.empty?

            game.stock_market.find_share_price(entity, directions)
          end

          def dividend_option_market_closes_viable_corporation?(game, entity, option)
            return false unless entity&.corporation?
            return false if entity == game.ic
            return false if remembered_closure_intent?(game, entity)
            return false unless market_close_viable_corporation?(game, entity)

            dividend_resulting_share_price(game, entity, option)&.types&.include?(:close)
          end

          def frozen_sold_out?(game, entity)
            return false unless entity&.corporation?
            return false unless game.frozen_corporations.include?(entity)

            entity.num_ipo_shares.zero? &&
              entity.num_ipo_reserved_shares.zero? &&
              entity.num_treasury_shares.zero?
          end

          def dividend_subsidy(step)
            step.respond_to?(:total_subsidy) ? step.total_subsidy : 0
          end

          def closure_hot_run?(game, entity)
            return false unless entity.corporation?
            return false unless entity.trains.any?
            return false unless closure_plan_score(game, entity) >= CLOSURE_ISSUE_SCORE_THRESHOLD

            !owns_permanent_train?(entity) || entity.num_market_shares.positive?
          end

          def dividend_train_options(game, entity)
            options = game.depot.depot_trains.flat_map do |train|
              train.variants.values.filter_map do |variant|
                next unless entity.trains.size < game.train_limit(entity)
                next unless valid_train_mix_after_purchase?(game, entity, variant, nil)

                {
                  name: variant[:name],
                  price: variant[:price] || train.price,
                  permanent: permanent_train_variant?(variant),
                }
              end
            end
            game.discountable_trains_for(entity).each do |exchange, depot_train, variant_name, price|
              variant = depot_train.variants.values.find { |candidate| candidate[:name] == variant_name }
              next unless variant
              next unless valid_train_mix_after_purchase?(game, entity, variant, exchange)

              options << {
                name: variant_name,
                price: price,
                permanent: permanent_train_variant?(variant),
              }
            end
            options
          end

          def planned_obsolescence_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::ObsoleteTrain)
            return unless actions.include?('choose')

            rusting_train = step.trains_rusting_for(entity, step.purchased_train).first
            if rusting_train&.name == '2' && !planned_obsolescence_worth_using_on_two?(entity)
              return unless actions.include?('pass')

              return Decision.new(
                action: Engine::Action::Pass.new(entity),
                reason: 'Saves Planned Obsolescence for a later train instead of preserving a 2-train',
              )
            end

            choice = step.choices.first
            return unless choice

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: choice),
              reason: "Uses Planned Obsolescence to retain #{choice}",
            )
          end

          def planned_obsolescence_worth_using_on_two?(corporation)
            return true if corporation.total_shares == 2

            president = corporation.owner
            return false unless president

            president.shares_of(corporation).sum(&:percent) >= 80
          end

          def option_cube_exchange_decision(_game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::ExchangeChoiceCorp)
            return unless actions.include?('choose')

            choice = step.choices.find { |candidate| candidate.start_with?('Pay ') && candidate.include?(' share') }
            return unless choice

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: choice),
              reason: 'Pays for the discounted IC share rather than selling the option cube',
            )
          end

          def merger_compensation_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::ExchangeChoicePlayer)
            return unless actions.include?('choose')

            share_choice = step.choices.find { |choice| choice.include?("share of #{game.ic.name}") }
            return unless share_choice

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: share_choice),
              reason: 'Takes the IC share as merger compensation',
            )
          end

          def merge_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Merge)
            return unless actions.include?('merge') || actions.include?('pass')

            corporation = step.mergee
            return unless corporation

            if merge_corporation?(game, corporation)
              Decision.new(
                action: Engine::Action::Merge.new(entity, corporation: corporation),
                reason: "Merges #{corporation.name} into IC because the IC engine is stronger than keeping it separate",
              )
            elsif actions.include?('pass')
              Decision.new(
                action: Engine::Action::Pass.new(entity),
                reason: "Keeps #{corporation.name} independent because its own engine is more valuable",
              )
            end
          end

          def merge_corporation?(game, corporation)
            merge_score(game, corporation).positive?
          end

          def merge_score(game, corporation)
            score = 0
            score += MERGE_WEAK_CORPORATION_BONUS if weak_stock_corporation?(game, corporation)
            score += MERGE_WEAK_CORPORATION_BONUS if merge_permanent_gap_matters?(game, corporation)
            score += closure_plan_score(game, corporation)
            score -= MERGE_STRONG_INDEPENDENT_PENALTY if mature_permanent_route?(game, corporation) &&
              owns_permanent_train?(corporation)
            score -= active_independent_merge_penalty(game, corporation)
            score -= healthy_independent_merge_penalty(game, corporation)

            score
          end

          def active_independent_merge_penalty(game, corporation)
            return 0 if weak_stock_corporation?(game, corporation)
            return 0 unless corporation.trains.size >= 2

            share_price = corporation.share_price&.price.to_i
            return 0 if share_price < MERGE_ACTIVE_OPERATOR_MIN_PRICE

            nodes = connected_revenue_nodes(game, corporation).size
            return 0 unless nodes >= MERGE_ACTIVE_OPERATOR_MIN_REVENUE_NODES ||
                            endpoint_pair_groups(game, corporation).positive? ||
                            mature_permanent_route?(game, corporation)

            MERGE_ACTIVE_OPERATOR_BASE_PENALTY +
              (corporation.trains.size * MERGE_ACTIVE_OPERATOR_TRAIN_PENALTY) +
              share_price +
              (corporation.cash / MERGE_ACTIVE_OPERATOR_CASH_DIVISOR) +
              (nodes * MERGE_ACTIVE_OPERATOR_NODE_PENALTY)
          end

          def healthy_independent_merge_penalty(game, corporation)
            return 0 if weak_stock_corporation?(game, corporation)
            return 0 unless mature_permanent_route?(game, corporation)

            share_price = corporation.share_price&.price.to_i
            return 0 if share_price < MERGE_HEALTHY_PRICE_THRESHOLD

            treasury_value = corporation.num_treasury_shares * share_price
            price_premium = share_price - MERGE_HEALTHY_PRICE_THRESHOLD
            MERGE_HEALTHY_INDEPENDENT_BASE_PENALTY +
              (price_premium * MERGE_HEALTHY_PRICE_PREMIUM_MULTIPLIER) +
              (corporation.cash / MERGE_HEALTHY_CASH_DIVISOR) +
              (treasury_value / MERGE_HEALTHY_TREASURY_DIVISOR)
          end

          def merge_permanent_gap_matters?(game, corporation)
            return false if owns_permanent_train?(corporation)
            return true if cheapest_available_permanent_train(game)
            return true if permanent_train_near?(game) && corporation.trains.empty?

            false
          end

          def train_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BuyTrain)
            return unless actions.include?('buy_train')

            receivership_train = receivership_ic_train_decision(game, step, entity)
            return receivership_train if receivership_train

            rush_delivery = step.is_a?(G18IL::Step::BuyTrainBeforeRunRoute)
            rush_permanent = false
            if rush_delivery
              return if entity.trains.empty? && game.turn == 1 && game.round.round_num == 1

              rush_permanent = !entity.trains.empty? && !owns_permanent_train?(entity) &&
                permanent_train_options(game, entity).any? { |option| option[:price] <= entity.cash }
              return unless entity.trains.empty? || rush_permanent
            end

            candidates = step.buyable_trains(entity).select do |train|
              bot_may_buy_train?(game, entity, train)
            end.flat_map do |train|
              step.train_variant_helper(train, entity).map do |variant|
                price = train_purchase_price(step, entity, train, variant)
                [train, variant, price, nil] if price
              end
            end.compact
            candidates.concat(discounted_train_candidates(game, step, entity))
            candidates.select! do |_train, variant, _price, exchange|
              valid_train_mix_after_purchase?(game, entity, variant, exchange)
            end
            candidates.select! { |_train, variant, _price, _exchange| permanent_train_variant?(variant) } if rush_permanent
            mandatory = !actions.include?('pass')
            if mandatory
              cash_funded = candidates.select { |_train, _variant, price, _exchange| price <= entity.cash }
              candidates = cash_funded unless cash_funded.empty?
            else
              candidates.select! { |_train, _variant, price, _exchange| price <= entity.cash }
            end
            unless mandatory
              candidates.reject! do |train, variant, _price, exchange|
                surplus_two_trains_after_purchase(game, entity, variant, exchange).positive? &&
                  !early_sibling_train_transfer?(game, entity, train) &&
                  closure_overtrain_bonus(game, entity, variant, exchange).zero?
              end
            end
            emergency = mandatory && candidates.none? do |_train, _variant, price, _exchange|
              price <= entity.cash
            end
            train, variant, price, exchange = if emergency
                                                candidates.min_by do |_train, _variant, candidate_price, candidate_exchange|
                                                  [candidate_price, candidate_exchange ? 0 : 1]
                                                end
                                              else
                                                candidates.max_by do |candidate_train, candidate_variant, candidate_price,
                                                                      candidate_exchange|
                                                  train_candidate_score(game, candidate_train, candidate_variant,
                                                                        candidate_price, candidate_exchange, entity)
                                                end
                                              end
            return unless train

            remember_closure_intent(game, train.owner, reason: :train_strip) if closure_train_strip_transfer?(game, entity, train)
            if train_funding_intent_bonus(game, entity, variant).positive?
              remember_train_funding_intent(
                game,
                entity,
                target: {
                  name: variant[:name],
                  price: price,
                  permanent: permanent_train_variant?(variant),
                },
                reason: :train_purchase,
              )
            end
            score = train_candidate_score(game, train, variant, price, exchange, entity)
            Decision.new(
              action: Engine::Action::BuyTrain.new(
                entity,
                train: train,
                variant: variant[:name],
                price: price,
                exchange: exchange,
              ),
              reason: train_purchase_reason(emergency, mandatory, variant, price, exchange, score),
            )
          end

          def receivership_ic_train_decision(game, step, entity)
            return unless entity == game.ic && game.ic_in_receivership?

            cheapest = step.cheapest_depot_train
            if cheapest && entity.trains.size < game.train_limit(entity) && entity.cash >= cheapest.price
              return Decision.new(
                action: Engine::Action::BuyTrain.new(
                  entity,
                  train: cheapest,
                  variant: cheapest.name,
                  price: cheapest.price,
                ),
                reason: "Receivership IC buys the forced cheapest Depot train, #{cheapest.name}",
              )
            end

            owned_train, depot_train, variant_name, price = game.discountable_trains_for(entity)
              .select { |_owned, depot, variant, upgrade_price| depot.name == 'D' && variant == 'D' && upgrade_price <= entity.cash }
              .min_by { |_owned, _depot, _variant, upgrade_price| upgrade_price }
            return unless depot_train

            Decision.new(
              action: Engine::Action::BuyTrain.new(
                entity,
                train: depot_train,
                variant: variant_name,
                price: price,
                exchange: owned_train,
              ),
              reason: 'Receivership IC upgrades to the forced D train',
            )
          end

          def bot_may_buy_train?(game, buyer, train)
            return true unless train.owned_by_corporation?

            strategic_train_transfer?(game, buyer, train) ||
              early_sibling_train_transfer?(game, buyer, train) ||
              closure_train_strip_transfer?(game, buyer, train)
          end

          def valid_train_mix_after_purchase?(game, entity, variant, exchange)
            valid_train_mix?(game, entity, variant, exchange: exchange)
          end

          def valid_train_mix_after_purchase_after_scrap?(game, entity, variant, exchange, scrapped_train)
            valid_train_mix?(game, entity, variant, exchange: exchange, scrapped_train: scrapped_train)
          end

          def valid_train_mix?(game, entity, variant, exchange: nil, scrapped_train: nil)
            limit = game.train_limit(entity)
            return true if limit <= 1

            trains = entity.trains.reject { |train| train == exchange || train == scrapped_train }.map(&:name)
            trains << variant[:name]
            return true if trains == %w[2 2] && two_run_network?(game, entity)

            trains.size < limit || trains.uniq.size > 1
          end

          def two_run_network?(game, entity)
            connected = game.graph_for_entity(entity).connected_nodes(entity).keys
            connected.count { |node| node.city? || node.offboard? } >= 3
          end

          def train_candidate_score(game, train, variant, price, exchange, entity)
            distance = variant[:distance] || train.distance
            capacity = train_distance_capacity(distance)
            permanent = variant[:rusts_on].nil? && variant[:obsolete_on].nil?
            surplus_two_penalty = surplus_two_train_penalty(game, entity, variant, exchange)
            strategic_transfer_bonus = strategic_train_transfer?(game, entity, train) ? STRATEGIC_TRAIN_TRANSFER_BONUS : 0
            early_transfer_bonus = early_sibling_train_transfer?(game, entity, train) ? EARLY_SIBLING_TRAIN_TRANSFER_BONUS : 0
            closure_bonus = closure_train_strip_transfer?(game, entity, train) ? CLOSURE_TRAIN_STRIP_BONUS : 0
            overtrain_bonus = closure_overtrain_bonus(game, entity, variant, exchange)
            zero_three_city_bonus = zero_three_city_train_bonus(game, entity, variant)
            three_train_rust_protection_bonus = three_train_rust_protection_bonus(game, entity, variant)
            rust_replacement_bonus = rust_replacement_train_bonus(game, entity, variant)
            funding_intent_bonus = train_funding_intent_bonus(game, entity, variant)
            acceleration_bonus = train_acceleration_bonus(game, entity, variant)

            (capacity * profile[:train_capacity_weight]) +
              (permanent ? profile[:train_permanent_bonus] : 0) -
              (price / profile[:train_price_divisor]) +
              (exchange ? profile[:train_exchange_bonus] : 0) -
              (entity.trains.size * profile[:train_count_penalty]) -
              surplus_two_penalty +
              strategic_transfer_bonus +
              early_transfer_bonus +
              closure_bonus +
              overtrain_bonus +
              zero_three_city_bonus +
              three_train_rust_protection_bonus +
              rust_replacement_bonus +
              funding_intent_bonus +
              acceleration_bonus
          end

          def train_acceleration_bonus(game, entity, variant)
            pressure = relative_train_pressure(game, entity)
            return 0 unless pressure.positive?

            score = train_roster_advancement?(game, variant) ? TRAIN_ACCELERATION_ROSTER_BONUS : 0
            rust_targets = train_rust_targets(game, variant)
            if rust_targets.any?
              score += TRAIN_ACCELERATION_RUST_BONUS
              score += TRAIN_ACCELERATION_LEADER_RUST_BONUS if rust_targets.any? do |corporation|
                corporation.owner == leading_player(game)
              end
            end
            return 0 unless score.positive?

            [score * pressure / 100, TRAILING_TRAIN_ACCELERATION_MAX_BONUS].min
          end

          def relative_train_pressure(game, entity)
            player = entity&.owner
            return 0 unless player&.player?

            values = game.players.to_h { |candidate| [candidate, game.player_value(candidate)] }
            leader_value = values.values.max.to_i
            player_value = values[player].to_i
            return 0 if player_value >= leader_value

            [[(leader_value - player_value) / TRAIN_ACCELERATION_VALUE_GAP_DIVISOR, 100].min, 0].max
          end

          def leading_player(game)
            game.players.max_by { |player| game.player_value(player) }
          end

          def train_roster_advancement?(game, variant)
            next_depot_train = game.depot.depot_trains.first
            next_depot_train && next_depot_train.variants.values.any? { |candidate| candidate[:name] == variant[:name] }
          end

          def train_rust_targets(game, variant)
            purchased_train = Struct.new(:sym).new(variant[:name])
            game.corporations.select do |corporation|
              corporation.trains.any? { |train| game.rust?(train, purchased_train) }
            end
          end

          def three_train_rust_protection_bonus(game, entity, variant)
            return 0 unless three_train_variant?(variant)
            return 0 unless needs_three_train_before_four?(game, entity)

            THREE_TRAIN_RUST_PROTECTION_BONUS
          end

          def rust_replacement_train_bonus(game, entity, variant)
            return 0 unless entity&.corporation?
            return 0 if entity.trains.empty?
            return 0 if owns_permanent_train?(entity)

            purchased_train = Struct.new(:sym).new(variant[:name])
            return 0 unless entity.trains.all? { |train| game.rust?(train, purchased_train) }

            RUST_REPLACEMENT_TRAIN_BONUS
          end

          def zero_three_city_train_bonus(game, entity, variant)
            return 0 unless zero_three_city_train_variant?(variant)
            return 0 unless strong_zero_three_city_network?(game, entity)

            ZERO_THREE_CITY_TRAIN_BONUS
          end

          def needs_three_train_before_four?(_game, entity)
            return false unless entity&.corporation?
            return false if entity.trains.empty?
            return false unless entity.trains.all? { |train| train.name == '2' }

            true
          end

          def early_sibling_train_transfer?(game, buyer, train)
            seller = train.owner
            train_name = train.respond_to?(:name) ? train.name : nil

            return false unless game
            return false unless seller&.corporation?
            return false unless buyer&.corporation?
            return false if seller == buyer || seller == game.ic || buyer == game.ic
            return false unless buyer.owner&.player? && buyer.owner == seller.owner
            return false unless buyer.total_shares == 2
            return false unless two_corporation_train_bank_pair?(buyer, seller)
            return false unless EARLY_SIBLING_TRAIN_TRANSFER_NAMES.include?(train_name)
            return false unless early_sibling_train_transfer_window?(game, train_name)
            return false unless buyer.cash.positive?
            return false unless buyer.trains.size < game.train_limit(buyer)
            return false unless buyer.trains.empty? || buyer.trains.size < early_sibling_train_transfer_target(game, buyer)
            return false unless seller.trains.include?(train)
            return false unless seller.trains.size > 1
            return false if train.respond_to?(:rusted) && train.rusted
            return false if train.respond_to?(:obsolete) && train.obsolete
            return false unless game.operated_this_round?(seller)

            true
          end

          def early_sibling_train_transfer_window?(game, train_name)
            next_train_name = game.depot.min_depot_train&.name
            next_train_rank = next_train_name.to_s[/\d+/].to_i
            return false unless next_train_rank.positive?

            case train_name
            when '2'
              next_train_rank <= 3
            when '3'
              next_train_rank <= 4
            else
              false
            end
          end

          def early_sibling_train_transfer_target(game, buyer)
            [2, game.train_limit(buyer)].min
          end

          def strong_zero_three_city_network?(game, entity)
            connected_revenue_nodes(game, entity).count(&:city?) >= ZERO_THREE_CITY_MIN_CITIES
          end

          def strategic_train_transfer?(game, buyer, train)
            seller = train.owner
            return false unless seller&.corporation?
            return false unless buyer&.corporation?
            return false if seller == buyer || seller == game.ic
            return false unless buyer.owner&.player? && buyer.owner == seller.owner
            return false unless buyer.trains.empty? || needs_permanent_train_transfer?(buyer)
            return false unless buyer.cash >= train.price
            return false unless train.rusts_on.nil? && train.obsolete_on.nil?
            return false unless game.operated_this_round?(seller)
            return false unless lower_value_corporation?(buyer, seller)

            target_price = strategic_train_transfer_target_price(game)
            return false unless target_price

            seller.cash < target_price &&
              seller.cash + train.price >= (target_price * STRATEGIC_TRAIN_TRANSFER_FUNDING_RATIO).ceil
          end

          def needs_permanent_train_transfer?(corporation)
            return false if owns_permanent_train?(corporation)
            return false unless corporation.trains.any?

            corporation.trains.all? { |train| train.rusts_on || train.obsolete_on }
          end

          def closure_train_strip_transfer?(game, buyer, train)
            return false unless game

            seller = train.owner
            return false unless seller&.corporation?
            return false unless buyer&.corporation?
            return false if seller == buyer || seller == game.ic || buyer == game.ic
            return false unless buyer.owner&.player? && buyer.owner == seller.owner
            return false unless game.operated_this_round?(seller)
            return false unless closure_plan_score(game, seller) >= CLOSURE_ISSUE_SCORE_THRESHOLD
            return false unless closure_support_candidate?(buyer)
            return false if game.operated_this_round?(buyer)

            buyer.cash.positive?
          end

          def closure_overtrain_bonus(game, entity, variant, exchange)
            return 0 unless closure_plan_score(game, entity) >= CLOSURE_ISSUE_SCORE_THRESHOLD
            return 0 if exchange
            return 0 unless variant[:rusts_on]

            CLOSURE_OVERTRAIN_BONUS * profile[:closure_strategy_weight] / 100
          end

          def lower_value_corporation?(buyer, seller)
            buyer_price = buyer.share_price&.price
            seller_price = seller.share_price&.price
            return false unless buyer_price && seller_price

            buyer_price <= seller_price
          end

          def strategic_train_transfer_target_price(game)
            cheapest_available_permanent_train(game)&.fetch(:price) || game.depot.min_depot_price
          end

          def surplus_two_train_penalty(game, entity, variant, exchange)
            surplus_two_trains_after_purchase(game, entity, variant, exchange) * SURPLUS_TWO_TRAIN_PENALTY
          end

          def surplus_two_trains_after_purchase(game, entity, variant, exchange)
            return 0 unless variant[:name] == '2'

            two_trains_after_purchase = entity.trains
              .reject { |train| train == exchange }
              .count { |train| train.name == '2' } + 1
            surplus = two_trains_after_purchase - expected_two_train_runs(game, entity)
            [surplus, 0].max
          end

          def expected_two_train_runs(game, entity)
            current_two_trains = entity.trains.select { |train| train.name == '2' }
            if current_two_trains.size >= 2
              runnable_twos = best_route_combination(game, entity, current_two_trains).count do |route|
                route&.train&.name == '2'
              end
              return [runnable_twos, 1].max
            end

            revenue_nodes = connected_revenue_nodes(game, entity).size
            return 1 if revenue_nodes < 3

            [revenue_nodes - 1, game.train_limit(entity)].min
          end

          def train_purchase_reason(emergency, mandatory, variant, price, exchange, score)
            purchase_type = if emergency
                              'cheapest emergency'
                            elsif mandatory
                              'best-valued mandatory'
                            else
                              'best-valued optional'
                            end
            exchange_text = exchange ? " by exchanging its #{exchange.name}" : ''
            "Buys the #{purchase_type} train, #{variant[:name]} for #{price}#{exchange_text} (train score #{score})"
          end

          def discard_train_decision(step, entity, actions)
            return unless step.is_a?(Engine::Step::DiscardTrain)
            return unless actions.include?('discard_train')

            train = step.trains(entity).min_by { |candidate| discard_train_score(entity, candidate) }
            return unless train

            Decision.new(
              action: Engine::Action::DiscardTrain.new(entity, train: train),
              reason: "Discards the least useful train, #{train.name}",
            )
          end

          def discard_train_score(entity, train)
            duplicate = entity.trains.count { |candidate| candidate.name == train.name } > 1
            [
              train.rusts_on.nil? && train.obsolete_on.nil? ? 1 : 0,
              duplicate ? 0 : 1,
              train_distance_capacity(train),
              train.name.to_i,
              train.price,
              train.id,
            ]
          end

          def train_distance_capacity(train_or_distance)
            distance = train_or_distance.respond_to?(:distance) ? train_or_distance.distance : train_or_distance
            return 10 if distance.is_a?(Numeric)

            city_distance = distance.find { |part| (part['nodes'] & %w[city offboard]).any? }
            [city_distance&.fetch('pay', 0).to_i, 10].min
          end

          def borrow_train_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::BorrowTrain)
            return unless actions.include?('borrow_train')

            train = step.borrowable_trains(entity).min_by(&:price)
            return unless train

            Decision.new(
              action: Engine::Action::BorrowTrain.new(entity, train: train),
              reason: "Borrows the cheapest available train, #{train.name}",
            )
          end

          def discounted_train_candidates(game, step, entity)
            game.discountable_trains_for(entity).filter_map do |owned_train, depot_train, variant_name, price|
              available = step.buyable_trains(entity).include?(depot_train) || game.depot.available(entity).include?(depot_train)
              next unless available

              variant = depot_train.variants.values.find { |candidate| candidate[:name] == variant_name }
              variant ||= { name: variant_name, price: depot_train.price }
              [depot_train, variant, price, owned_train]
            end
          end

          def train_purchase_price(step, entity, train, variant)
            return variant[:price] || train.price if train.from_depot?
            return unless entity.owner

            minimum, maximum = step.spend_minmax(entity, train)
            game = step.instance_variable_get(:@game)
            return minimum if early_sibling_train_transfer?(game, entity, train)
            return minimum if closure_train_strip_transfer?(game, entity, train)

            if step.must_buy_at_face_value?(train, entity)
              return train.price if (minimum..maximum).cover?(train.price)

              return
            end

            price = [entity.cash, maximum].min
            price if price >= minimum
          end

          def track_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Track)
            return unless actions.include?('lay_tile')

            tile_lay = step.get_tile_lay(entity)
            return unless tile_lay

            candidates = game.hexes.flat_map do |hex|
              next [] unless step.available_hex(entity, hex)

              safely_upgradeable_tiles(step, entity, hex).flat_map do |tile|
                tile.legal_rotations.filter_map do |rotation|
                  rotated_tile = safely_rotated_tile(tile, rotation)
                  next unless rotated_tile

                  next unless ic_line_tile_valid?(game, hex, rotated_tile)
                  next if city_upgrade_stranded_approach?(hex, rotated_tile)
                  next if permanently_stranded_revenue_approach?(game, hex, rotated_tile)

                  cost = track_cost(hex, rotated_tile, tile_lay)
                  next if cost > entity.cash

                  score = track_candidate_score(game, hex, rotated_tile, cost, entity)
                  route_critical = route_critical_track?(game, entity, hex, tile, rotation, rotated_tile)
                  route_progress = route_progress_track?(game, entity, hex, rotated_tile)
                  next unless preserves_train_funds?(game, entity, cost) || route_critical || route_progress

                  score += URGENT_ROUTE_CREATION_BONUS if route_critical
                  score += URGENT_ROUTE_PROGRESS_BONUS if route_progress && !route_critical
                  [hex, tile, rotation, cost, score]
                end
              end
            end
            candidates = add_route_revenue_lookahead(game, entity, candidates)
            hex, tile, rotation, cost, score = candidates.min_by do |candidate_hex, candidate_tile, candidate_rotation,
                                                                      candidate_cost, candidate_score|
              [-candidate_score, candidate_cost, candidate_hex.id, candidate_tile.name, candidate_rotation]
            end
            return unless hex

            Decision.new(
              action: Engine::Action::LayTile.new(entity, hex: hex, tile: tile, rotation: rotation),
              reason: "Lays #{tile.name} on #{hex.id} for #{cost} (track score #{score})",
            )
          end

          def safely_rotated_tile(tile, rotation)
            tile.dup.rotate!(rotation)
          rescue FrozenError, TypeError
            nil
          end

          def add_route_revenue_lookahead(game, entity, candidates)
            return candidates if candidates.empty?
            return candidates unless entity.corporation?
            return candidates if entity.trains.empty?
            return candidates if IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_LIMIT <= 0
            return candidates if game.raw_actions.size > IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_MAX_ACTIONS

            shortlist = candidates.min_by(IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_LIMIT) do |candidate_hex, candidate_tile,
                                                                                       candidate_rotation,
                                                                                       candidate_cost,
                                                                                       candidate_score|
              [-candidate_score, candidate_cost, candidate_hex.id, candidate_tile.name, candidate_rotation]
            end
            shortlist.each do |candidate|
              hex, tile, rotation, _cost, score = candidate
              candidate[4] = score + (immediate_route_revenue_after_lay(game, entity, hex, tile, rotation) *
                IMMEDIATE_ROUTE_REVENUE_TRACK_MULTIPLIER)
            end
            candidates
          end

          def safely_upgradeable_tiles(step, entity, hex)
            step.upgradeable_tiles(entity, hex)
          rescue TypeError => e
            singleton_tile_error = e.message.include?("can't create instance of singleton class") ||
              e.message.include?('wrong instance allocation')
            raise unless singleton_tile_error

            []
          end

          def track_cost(hex, tile, tile_lay)
            action_cost = tile.color == :yellow ? tile_lay[:cost] : tile_lay[:upgrade_cost]
            terrain_cost = hex.tile.upgrades.sum(&:cost)
            border_cost = hex.tile.borders.sum { |border| border.cost || 0 }
            action_cost + terrain_cost + border_cost
          end

          def immediate_route_revenue_after_lay(game, entity, hex, tile, rotation)
            return 0 unless entity.corporation?
            return 0 if entity.trains.empty?

            clone = game.clone(game.raw_actions)
            clone_entity = clone.corporation_by_id(entity.id)
            clone_hex = clone.hex_by_id(hex.id)
            clone_step = clone.round.active_step
            return 0 unless clone_step.is_a?(G18IL::Step::Track)

            clone_tile = clone_step.upgradeable_tiles(clone_entity, clone_hex).find { |candidate| candidate.name == tile.name }
            return 0 unless clone_tile

            clone.process_action(Engine::Action::LayTile.new(clone_entity, hex: clone_hex, tile: clone_tile, rotation: rotation))
            return 0 if clone.exception

            route_step = clone.round.active_step
            return 0 unless route_step.is_a?(G18IL::Step::Route)
            return 0 unless route_step.actions(clone_entity).include?('run_routes')

            finder = RouteFinder.new(clone)
            routes = sampled_route_combination(clone, clone_entity, clone.route_trains(clone_entity), finder)
            route_combination_revenue(clone, routes)
          rescue StandardError
            0
          end

          def track_candidate_score(game, hex, tile, cost, entity)
            old_exits = hex.tile.exits
            new_exits = (tile.exits - old_exits).size
            neighbor_connections = tile.exits.count do |edge|
              neighbor = hex.neighbors[edge]
              neighbor && neighbor.paths[hex.invert(edge)].any?
            end
            revenue = tile.nodes.sum { |node| revenue_center_value(game, node) }
            home_bonus = if entity.coordinates == hex.id && hex.tile.color == :white
                           profile[:track_home_bonus]
                         else
                           0
                         end
            ic_line_bonus = ic_line_progress_score(game, entity, hex, tile)
            opening_link_bonus = corporation_opening_link_score(game, entity, hex, tile)
            route_creation_bonus = route_creation_score(game, entity, hex, tile)
            destination_progress_bonus = revenue_destination_progress_score(game, entity, hex, tile)
            high_value_access_bonus = high_value_route_access_score(game, entity, hex, tile)
            endpoint_pair_bonus = route_endpoint_pair_progress_score(game, entity, hex, tile)
            permanent_repair_bonus = permanent_route_repair_score(game, entity, destination_progress_bonus,
                                                                  high_value_access_bonus, endpoint_pair_bonus)
            stranded_approach_penalty = city_upgrade_stranded_approach_penalty(hex, tile)
            high_value_city_bonus = HIGH_VALUE_CITY_HEXES.include?(hex.id) ? HIGH_VALUE_TRACK_BONUS : 0
            boom_city_upgrade_bonus = if route_capacity_satisfied?(game, entity) &&
              game.class::BOOM_HEXES.include?(hex.id) &&
              tile.color != hex.tile.color
                                        BOOM_CITY_UPGRADE_BONUS
                                      else
                                        0
                                      end

            home_bonus + (neighbor_connections * profile[:track_neighbor_weight]) +
              (new_exits * profile[:track_new_exit_weight]) + (revenue * profile[:track_revenue_weight]) +
              (tile.cities.size * profile[:track_city_weight]) + route_creation_bonus +
              destination_progress_bonus + high_value_access_bonus + endpoint_pair_bonus + high_value_city_bonus +
              permanent_repair_bonus + boom_city_upgrade_bonus + ic_line_bonus + opening_link_bonus -
              stranded_approach_penalty - cost
          end

          def city_upgrade_stranded_approach_penalty(hex, tile)
            tile.exits.sum do |edge|
              neighbor = hex.neighbors[edge]
              required_exits = CITY_UPGRADE_EXIT_REQUIREMENTS[neighbor&.id]
              next 0 unless required_exits

              required_exits.include?(hex.invert(edge)) ? 0 : CITY_UPGRADE_STRANDED_APPROACH_PENALTY
            end
          end

          def city_upgrade_stranded_approach?(hex, tile)
            city_upgrade_stranded_approach_penalty(hex, tile).positive?
          end

          def permanently_stranded_revenue_approach?(game, hex, tile)
            (tile.exits - hex.tile.exits).any? do |edge|
              neighbor = hex.neighbors[edge]
              next false unless neighbor
              next false unless neighbor.tile.nodes.any? { |node| node.city? || node.town? || node.offboard? }

              incoming_edge = hex.invert(edge)
              !revenue_edge_eventually_available?(game, neighbor, incoming_edge)
            end
          end

          def revenue_edge_eventually_available?(game, hex, edge)
            return true if hex.paths[edge].any?

            game.all_tiles.uniq.any? do |candidate|
              candidate.legal_rotations.any? do |rotation|
                tile = safely_rotated_tile(candidate, rotation)
                next false unless tile

                tile.hex = hex
                game.upgrades_to?(hex.tile, tile) && tile.exits.include?(edge)
              end
            end
          end

          def permanent_route_repair_score(game, entity, *scores)
            return 0 unless entity.corporation?
            return 0 unless owns_permanent_train?(entity)
            return 0 if mature_permanent_route?(game, entity)

            scores.sum * PERMANENT_ROUTE_REPAIR_MULTIPLIER
          end

          def high_value_route_access_score(game, entity, hex, tile)
            connected_hexes = game.graph_for_entity(entity).connected_hexes(entity)
            tile.exits.filter_map do |edge|
              neighbor = hex.neighbors[edge]
              next unless neighbor
              next if connected_hexes[neighbor]

              future_value = REVENUE_DESTINATION_VALUES.fetch(neighbor.id, 0)
              next unless future_value.positive?

              future_value * HIGH_VALUE_ROUTE_ACCESS_MULTIPLIER
            end.max.to_i
          end

          def route_endpoint_pair_progress_score(game, entity, hex, tile)
            return 0 unless entity.corporation?
            return 0 unless entity.trains.any? || cheapest_available_permanent_train(game)

            groups = connected_route_groups(game, entity)
            missing_targets = []
            missing_targets.concat(endpoint_group_targets(game, groups, 'East', 'West'))
            missing_targets.concat(endpoint_group_targets(game, groups, 'North', 'South'))
            return 0 if missing_targets.empty?

            tile_groups = tile.nodes.flat_map(&:groups).uniq
            direct = missing_targets.count { |_id, group| tile_groups.include?(group) } * ENDPOINT_PAIR_TRACK_BONUS
            progress = (tile.exits - hex.tile.exits).sum do |edge|
              neighbor = hex.neighbors[edge]
              next 0 unless neighbor

              if missing_targets.any? do |target_id, _group|
                target = game.hex_by_id(target_id)
                target && neighbor.distance(target) < hex.distance(target)
              end
                ENDPOINT_PAIR_TRACK_BONUS / ENDPOINT_PAIR_TRACK_PROGRESS_DIVISOR
              else
                0
              end
            end
            direct + progress
          end

          def endpoint_group_targets(_game, groups, left_group, right_group)
            left_targets = { 'East' => %w[I6 I12 I18], 'North' => %w[G2] }
            right_targets = { 'West' => %w[A10 B3], 'South' => %w[F25] }
            return [] if groups.include?(left_group) && groups.include?(right_group)

            targets = []
            targets += right_targets.fetch(right_group, []).map { |id| [id, right_group] } if groups.include?(left_group)
            targets += left_targets.fetch(left_group, []).map { |id| [id, left_group] } if groups.include?(right_group)
            if targets.empty?
              targets = (left_targets.fetch(left_group, []).map { |id| [id, left_group] } +
                right_targets.fetch(right_group, []).map { |id| [id, right_group] })
            end
            targets
          end

          def corporation_opening_link_score(game, entity, hex, tile)
            return 0 unless entity.id == 'C&EI'

            connected_ids = game.graph_for_entity(entity).connected_hexes(entity).keys.map(&:id)
            required_hex, endpoints = if !connected_ids.include?('G24')
                                        ['G22', %w[H21 G24]]
                                      elsif !connected_ids.include?('I18')
                                        ['H19', %w[H21 I18]]
                                      elsif entity.trains.size >= 3 && !connected_ids.include?('F23')
                                        if connected_ids.include?('F21')
                                          ['F21', %w[G20 F23]]
                                        else
                                          ['G20', %w[H21 F21]]
                                        end
                                      elsif entity.trains.size >= 3 && hex.id == 'G20'
                                        # Once the third 2-train route is established, turn its G20
                                        # junction north-west so later lays can reach the IC Line.
                                        return tile_exits_toward?(hex, tile, 'F19') ? CORPORATION_OPENING_LINK_BONUS : 0
                                      end
            return 0 unless required_hex == hex.id
            return 0 unless endpoints.all? { |endpoint| tile_exits_toward?(hex, tile, endpoint) }

            CORPORATION_OPENING_LINK_BONUS
          end

          def tile_exits_toward?(hex, tile, neighbor_id)
            edge = hex.neighbors.find { |_edge, neighbor| neighbor.id == neighbor_id }&.first
            edge && tile.exits.include?(edge)
          end

          def route_creation_score(game, entity, hex, tile)
            return 0 if route_capacity_satisfied?(game, entity)

            targets = nearest_route_city_hexes(game, entity)
            return 0 if targets.empty?

            destination_bonus = targets.include?(hex) ? ROUTE_CREATION_DESTINATION_BONUS : 0
            progress = progressing_exits(hex, tile, targets)
            destination_bonus + (progress * ROUTE_CREATION_PROGRESS_BONUS)
          end

          def route_critical_track?(game, entity, hex, _tile, _rotation, rotated_tile)
            return false unless entity.corporation?
            return false if city_route_available?(game, entity)

            route_creation_score(game, entity, hex, rotated_tile).positive?
          end

          def route_progress_track?(game, entity, hex, rotated_tile)
            return false unless entity.corporation?
            return false if route_capacity_satisfied?(game, entity)

            route_creation_score(game, entity, hex, rotated_tile).positive?
          end

          def route_creation_funding_needed?(game, entity, proceeds)
            return false if route_capacity_satisfied?(game, entity)

            current_cost = route_creation_track_cost(game, entity, available_cash: entity.cash)
            funded_cost = route_creation_track_cost(game, entity, available_cash: entity.cash + proceeds)
            return false unless funded_cost

            !current_cost || !preserves_train_funds?(game, entity, funded_cost)
          end

          def route_creation_track_cost(game, entity, available_cash:)
            step = game.round.steps.find { |candidate| candidate.is_a?(G18IL::Step::Track) }
            return unless step

            tile_lay = step.get_tile_lay(entity)
            return unless tile_lay

            game.hexes.filter_map do |hex|
              next unless step.available_hex(entity, hex)

              safely_upgradeable_tiles(step, entity, hex).filter_map do |tile|
                tile.legal_rotations.filter_map do |rotation|
                  rotated_tile = safely_rotated_tile(tile, rotation)
                  next unless rotated_tile

                  next unless ic_line_tile_valid?(game, hex, rotated_tile)
                  next if city_upgrade_stranded_approach?(hex, rotated_tile)
                  next if permanently_stranded_revenue_approach?(game, hex, rotated_tile)

                  cost = track_cost(hex, rotated_tile, tile_lay)
                  next if cost > available_cash
                  next unless route_critical_track?(game, entity, hex, tile, rotation, rotated_tile) ||
                    route_progress_track?(game, entity, hex, rotated_tile)

                  cost
                end
              end
            end.flatten.min
          rescue StandardError
            nil
          end

          def nearest_route_city_hexes(game, entity)
            connected = game.graph_for_entity(entity).connected_nodes(entity)
            if city_route_available?(game, entity)
              network_hexes = game.graph_for_entity(entity).connected_hexes(entity).keys
              network_hexes = Array(entity.coordinates).filter_map { |id| game.hex_by_id(id) } if network_hexes.empty?
            else
              network_hexes = Array(entity.coordinates).filter_map { |id| game.hex_by_id(id) }
            end
            return [] if network_hexes.empty?

            destinations = game.hexes.select do |candidate|
              (candidate.tile.cities.any? || candidate.tile.offboards.any?) &&
                candidate.tile.nodes.none? { |node| connected[node] }
            end
            destination = destinations.min_by do |candidate|
              [network_hexes.map { |hex| hex.distance(candidate) }.min, candidate.id]
            end
            destination ? [destination] : []
          end

          def city_route_available?(game, entity)
            connected_revenue_nodes(game, entity).size >= 2
          end

          def route_capacity_satisfied?(game, entity)
            desired_revenue_nodes = [entity.trains.size + 1, 2].max
            connected_revenue_nodes(game, entity).size >= desired_revenue_nodes
          end

          def connected_revenue_nodes(game, entity)
            connected = game.graph_for_entity(entity).connected_nodes(entity)
            connected.keys.select { |node| node.city? || node.offboard? }
          end

          def progressing_exits(hex, tile, targets)
            (tile.exits - hex.tile.exits).count do |edge|
              neighbor = hex.neighbors[edge]
              next false unless neighbor

              targets.any? { |target| neighbor.distance(target) < hex.distance(target) }
            end
          end

          def revenue_destination_progress_score(game, entity, hex, tile)
            connected = game.graph_for_entity(entity).connected_nodes(entity)
            network_hexes = game.graph_for_entity(entity).connected_hexes(entity).keys
            network_hexes = Array(entity.coordinates).filter_map { |id| game.hex_by_id(id) } if network_hexes.empty?
            return 0 if network_hexes.empty?

            targets = revenue_destination_values(entity, connected).filter_map do |id, future_value|
              target = game.hex_by_id(id)
              next if !target || target.tile.nodes.any? { |node| connected[node] }

              distances = hex_build_distances(target)
              construction_distance = network_hexes.reject { |network_hex| network_hex == target }
                .filter_map { |network_hex| distances[network_hex] }.min
              next unless construction_distance

              priority = DESTINATION_PROGRESS_BASE +
                (future_value * DESTINATION_PROGRESS_SCALE.to_f / [construction_distance, 1].max).round
              [target, priority, construction_distance, distances]
            end.sort_by { |target, priority, _distance, _distances| [-priority, target.id] }
              .take(STRATEGIC_TARGET_COUNT)
            return 0 if targets.empty?

            (tile.exits - hex.tile.exits).filter_map do |edge|
              neighbor = hex.neighbors[edge]
              next unless neighbor

              targets.filter_map do |target, priority, construction_distance, distances|
                hex_distance = distances[hex]
                neighbor_distance = distances[neighbor]
                next unless hex_distance && neighbor_distance && neighbor_distance < hex_distance
                next unless hex_distance <= construction_distance
                next unless strategic_exit_viable?(game, entity, neighbor, hex.invert(edge), target)

                priority
              end.max
            end.max.to_i
          end

          def revenue_destination_values(entity, connected)
            values = REVENUE_DESTINATION_VALUES.dup
            values.merge!(CORPORATION_REVENUE_DESTINATION_VALUES.fetch(entity.id, {}))
            return values unless entity.companies.any? { |company| company.id == 'ICC' }

            groups = connected.keys.flat_map(&:groups).uniq
            east = %w[I6 I12 I18]
            west = %w[A10 B3]
            unless groups.include?('East') && groups.include?('West')
              targets = if groups.include?('West')
                          east
                        elsif groups.include?('East')
                          west
                        else
                          east + west
                        end
              targets.each { |id| values[id] = [values.fetch(id, 0), ICC_EW_DESTINATION_VALUE].max }
            end

            unless groups.include?('North') && groups.include?('South')
              targets = if groups.include?('North')
                          ['F25']
                        else
                          groups.include?('South') ? ['G2'] : %w[G2 F25]
                        end
              targets.each { |id| values[id] = [values.fetch(id, 0), ICC_NS_DESTINATION_VALUE].max }
            end
            values
          end

          def hex_build_distances(target)
            cached = @hex_build_distances_cache[target.id]
            return cached if cached

            distances = { target => 0 }
            queue = [target]
            queue.each do |hex|
              hex.neighbors.each_value do |neighbor|
                next if distances.key?(neighbor)

                distances[neighbor] = distances[hex] + 1
                queue << neighbor
              end
            end
            @hex_build_distances_cache[target.id] = distances
          end

          def strategic_exit_viable?(game, entity, neighbor, incoming_edge, target)
            return destination_accepts_edge?(game, target, incoming_edge) if neighbor == target
            return true if neighbor.tile.towns.empty?

            cvcc = entity.companies.find { |company| company.id == 'CVCC' }
            game.all_tiles.uniq.select do |candidate|
              normal_upgrade = game.upgrades_to?(neighbor.tile, candidate)
              cvcc_upgrade = cvcc && candidate.name == '838' &&
                game.upgrades_to?(neighbor.tile, candidate, true, selected_company: cvcc)
              (normal_upgrade || cvcc_upgrade) && game.phase.tiles.include?(candidate.color)
            end.any? do |candidate|
              candidate.legal_rotations.any? do |rotation|
                tile = safely_rotated_tile(candidate, rotation)
                next false unless tile

                next false unless (neighbor.tile.exits - tile.exits).empty?
                next false unless tile.exits.include?(incoming_edge)

                tile.exits.any? do |exit|
                  onward = neighbor.neighbors[exit]
                  onward && onward.distance(target) < neighbor.distance(target)
                end
              end
            end
          end

          def destination_accepts_edge?(game, target, incoming_edge)
            return [1, 5].include?(incoming_edge) if target.id == game.class::SPRINGFIELD_HEX.first &&
              target.tile.color == :white

            target.tile.exits.include?(incoming_edge)
          end

          def ic_line_progress_score(game, entity, hex, tile)
            return 0 unless game.class::IC_LINE_ORIENTATION[hex.id]

            old_connections = ic_line_connections(game, hex, hex.tile)
            new_connections = ic_line_connections(game, hex, tile)
            return 0 if new_connections <= old_connections

            base = new_connections >= 2 ? IC_LINE_COMPLETION_BONUS : IC_LINE_PROGRESS_BONUS
            cubes = entity.corporation? ? game.option_cube_count(entity) : 0
            urgency = ic_line_urgency_bonus(game, hex, tile, new_connections)
            ((base + urgency) * (1 + (cubes * 0.5))).round
          end

          def ic_line_urgency_bonus(game, hex, tile, new_connections)
            completed = ic_line_completed_hex_ids(game)
            return 0 if completed.include?(hex.id)

            missing_count = game.class::IC_LINE_COUNT - completed.size
            bonus = 0
            bonus += IC_LINE_CITY_URGENCY_BONUS if game.class::IC_LINE_CITY_HEXES.include?(hex.id)
            bonus += IC_LINE_H7_URGENCY_BONUS if hex.id == 'H7'
            bonus += IC_LINE_FUTURE_COMPLETION_BONUS if ic_line_future_completion_possible?(game, hex, tile)
            bonus += IC_LINE_NEAR_COMPLETE_URGENCY_BONUS if completed.size >= 8
            bonus += IC_LINE_FINAL_HEX_URGENCY_BONUS if missing_count <= 1
            bonus += IC_LINE_LATE_PHASE_URGENCY_BONUS if IC_LINE_LATE_PHASES.include?(game.phase.name)
            bonus += IC_LINE_COMPLETION_BONUS if new_connections >= 2
            bonus
          end

          def ic_line_future_completion_possible?(game, hex, tile)
            exits = game.class::IC_LINE_ORIENTATION[hex.id]
            return false unless exits
            return false unless tile.color == :yellow

            required_exits = (tile.exits | exits).uniq
            game.tiles.any? do |upgrade|
              next false unless upgrade.color == :green
              next false unless upgrade.label.to_s == tile.label.to_s

              (0..5).any? do |rotation|
                rotated = safely_rotated_tile(upgrade, rotation)
                next false unless rotated

                (required_exits - rotated.exits).empty?
              end
            end
          rescue StandardError
            false
          end

          def ic_line_completed_hex_ids(game)
            Array(game.instance_variable_get(:@ic_line_completed_hexes)).map(&:id)
          end

          def revenue_center_value(game, node)
            return 0 unless node.respond_to?(:revenue)

            game.phase.tiles.reverse_each do |color|
              revenue = node.revenue[color]
              return revenue if revenue
            end
            0
          end

          def token_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Token)
            return unless actions.include?('place_token')
            return if game.round.tokened
            return if reserve_last_token_for_gtl?(game, entity)

            city, slot, score, _cost = token_candidates(game, step, entity).min_by do |candidate_city, candidate_slot,
                                                                                     candidate_score, candidate_cost|
              [-candidate_score, candidate_cost, candidate_city.hex.id, candidate_city.index, candidate_slot || -1]
            end
            return unless city
            return if score < profile[:token_score_threshold]

            Decision.new(
              action: Engine::Action::PlaceToken.new(entity, city: city, slot: slot),
              reason: "Places a token in #{city.hex.id} (token score #{score})",
            )
          end

          def reserve_last_token_for_gtl?(game, entity)
            gtl = entity.companies.find { |company| company.id == 'GTL' }
            return false if !gtl || game.private_used?(gtl)

            entity.tokens.count { |token| !token.used } <= 1
          end

          def token_candidates(game, step, entity)
            game.hexes.flat_map do |hex|
              next [] unless step.available_hex(entity, hex)

              hex.tile.cities.filter_map do |city|
                slot = token_slot(entity, city)
                slot ||= abandoned_token_slot(entity, city)
                connected = game.token_graph_for_entity(entity).connected_nodes(entity)[city]
                normal_placement = !entity.tokens.all?(&:used) && connected && city.tokenable?(entity)
                stl_placement = game.class::STL_TOKEN_HEX.include?(hex.id)
                next if !normal_placement && !stl_placement && !slot

                cost = token_placement_cost(step, entity, slot)
                next if cost > entity.cash
                next unless preserves_train_funds?(game, entity, cost)

                score = token_candidate_score(game, city, slot)
                [city, slot, score, cost]
              end
            end
          end

          def token_slot(entity, city)
            city.tokens.index do |token|
              token&.status == :flipped && token.corporation == entity
            end
          end

          def abandoned_token_slot(entity, city)
            return if city.tokens.any? { |token| token&.corporation == entity && token.status != :flipped }

            city.tokens.index { |token| token&.status == :flipped }
          end

          def token_candidate_score(game, city, slot)
            hex = city.hex
            score = (revenue_center_value(game, city) * profile[:token_revenue_weight]) +
              (city.paths.size * profile[:token_path_weight]) +
              (city.available_slots.to_i * profile[:token_slot_weight])
            score += profile[:token_chicago_bonus] if game.class::CHICAGO_HEX.include?(hex.id)
            score += HIGH_VALUE_TOKEN_BONUS if HIGH_VALUE_CITY_HEXES.include?(hex.id)
            score += STRATEGIC_ANCHOR_TOKEN_BONUS if strategic_anchor_token_hex?(game, hex.id)
            score += strategic_anchor_denial_bonus(game, city)
            score += ENDPOINT_PAIR_TOKEN_BONUS if endpoint_pair_token_hex?(hex)
            score += IC_LINE_TOKEN_BONUS if game.class::IC_LINE_CITY_HEXES.include?(hex.id)
            future_value = REVENUE_DESTINATION_VALUES.fetch(hex.id, 0)
            score += future_value * TOKEN_FUTURE_VALUE_MULTIPLIER
            score += profile[:token_st_louis_bonus] if game.class::STL_TOKEN_HEX.include?(hex.id)
            score += profile[:token_ic_line_bonus] if game.class::IC_LINE_CITY_HEXES.include?(hex.id)
            score += profile[:token_replacement_bonus] if slot
            score += token_crowding_urgency(city) if premium_token_hex?(game, hex)
            score
          end

          def endpoint_pair_token_hex?(hex)
            %w[A10 B3 G2 F25 I6 I12 I18].include?(hex.id)
          end

          def strategic_anchor_token_hex?(game, hex_id)
            STRATEGIC_ANCHOR_TOKEN_HEXES.include?(hex_id) ||
              game.class::STL_TOKEN_HEX.include?(hex_id)
          end

          def strategic_anchor_denial_bonus(game, city)
            return 0 unless strategic_anchor_token_hex?(game, city.hex.id)

            token_owners = city.tokens.compact.map(&:corporation).compact.map(&:owner).compact.uniq
            token_owners.size.positive? ? STRATEGIC_ANCHOR_DENIAL_BONUS : 0
          end

          def strategic_anchor_tokens(corporation)
            corporation.tokens.select do |token|
              token.used && token.hex && STRATEGIC_ANCHOR_TOKEN_HEXES.include?(token.hex.id)
            end
          end

          def premium_token_hex?(game, hex)
            strategic_anchor_token_hex?(game, hex.id) ||
              HIGH_VALUE_CITY_HEXES.include?(hex.id) ||
              endpoint_pair_token_hex?(hex) ||
              game.class::IC_LINE_CITY_HEXES.include?(hex.id) ||
              game.class::STL_TOKEN_HEX.include?(hex.id)
          end

          def token_crowding_urgency(city)
            open_slots = city.available_slots.to_i
            return 180 if open_slots <= 1
            return 90 if open_slots == 2

            0
          end

          def token_placement_cost(step, entity, slot)
            return G18IL::Step::Token::TOKEN_REPLACEMENT_COST if slot || entity.tokens.all?(&:used)

            step.available_tokens(entity).map(&:price).min || 0
          end

          def preserves_train_funds?(game, entity, cost)
            return true if cost.zero?
            return true unless entity.corporation?
            return true unless entity.trains.empty?

            entity.cash - cost >= game.depot.min_depot_price
          end

          def ic_line_tile_valid?(game, hex, tile)
            exits = game.class::IC_LINE_ORIENTATION[hex.id]
            return true unless exits

            connections = ic_line_connections(game, hex, tile)
            return connections.positive? if tile.color == :yellow
            return connections >= 2 if tile.color == :green

            true
          end

          def ic_line_connections(game, hex, tile)
            exits = game.class::IC_LINE_ORIENTATION[hex.id]
            return 0 unless exits

            tile.paths.sum { |path| path.exits.count { |exit| exits.include?(exit) } }
          end

          def forced_choice_decision(step, entity, actions)
            return unless actions.include?('choose')
            return if actions.include?('pass')
            return unless step.respond_to?(:choices)

            choices = step.choices
            choice = choices.is_a?(Hash) ? choices.keys.first : Array(choices).first
            return unless choice

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: choice),
              reason: "Selects the first forced choice, #{choice}",
            )
          end

          def route_extension_decision(_game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::RouteExtension)
            return unless actions.include?('choose')

            train = entity.trains.reject { |candidate| candidate.name == 'D' }
                          .max_by { |candidate| route_extension_distance(candidate) }
            train ||= entity.trains.first
            return unless train

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: train.id),
              reason: "Uses Route Extension on the #{train.name} train",
            )
          end

          def route_extension_distance(train)
            return train.distance if train.distance.is_a?(Numeric)

            group = train.distance.find { |distance| (distance['nodes'] & %w[city offboard]).any? }
            group ? group['visit'] : 0
          end

          def scrap_train_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Route)
            return unless actions.include?('scrap_train')

            train, permanent, lost_revenue = scrap_for_permanent_candidate(game, step, entity)
            return unless train

            remember_train_funding_intent(game, entity, target: permanent, reason: :scrap_train)
            Decision.new(
              action: Engine::Action::ScrapTrain.new(entity, train: train),
              reason: "Scraps its cheapest train, #{train.name}, to open a slot for the " \
                      "#{permanent[:name]} permanent train after giving up about #{lost_revenue} revenue",
            )
          end

          def scrap_for_permanent_candidate(game, step, entity)
            return unless entity.corporation?
            return if owns_permanent_train?(entity)
            return unless entity.trains.size >= game.train_limit(entity)

            train = step.scrappable_trains(entity).min_by { |candidate| scrap_train_order(candidate) }
            return unless train

            permanent = permanent_train_options_after_scrap(game, entity, train).min_by { |option| option[:price] }
            return unless permanent

            full_revenue = route_revenue_without_train(game, entity, nil)
            revenue_after_scrap = route_revenue_without_train(game, entity, train)
            return unless entity.cash + revenue_after_scrap >= permanent[:price]

            lost_revenue = [full_revenue - revenue_after_scrap, 0].max
            return if lost_revenue > scrap_for_permanent_loss_allowance(full_revenue)

            [train, permanent, lost_revenue]
          end

          def scrap_train_order(train)
            [
              train.price,
              train.rusts_on.nil? && train.obsolete_on.nil? ? 1 : 0,
              train_distance_capacity(train),
              train.id,
            ]
          end

          def scrap_for_permanent_loss_allowance(full_revenue)
            [
              SCRAP_FOR_PERMANENT_BASE_LOSS_ALLOWANCE,
              (full_revenue * SCRAP_FOR_PERMANENT_REVENUE_LOSS_RATIO).round,
            ].max
          end

          def route_revenue_without_train(game, entity, removed_train)
            trains = game.route_trains(entity).reject { |train| train == removed_train }
            route_combination_revenue(game, best_route_combination(game, entity, trains))
          rescue StandardError
            0
          end

          def route_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::Route)
            return unless actions.include?('run_routes')

            trains = game.route_trains(entity)
            routes = best_route_combination(game, entity, trains)
            if routes.empty?
              return Decision.new(
                action: Engine::Action::RunRoutes.new(entity, routes: []),
                reason: 'Runs no route because no valid route combination was found',
              )
            end

            Decision.new(
              action: Engine::Action::RunRoutes.new(entity, routes: routes),
              reason: "Runs the highest-revenue combination found for #{routes.size} train#{routes.one? ? '' : 's'}",
            )
          end

          def best_route_combination(game, corporation, trains)
            cached = valid_cached_routes(game, corporation, trains)

            finder = RouteFinder.new(game)
            routes = cached || sampled_route_combination(game, corporation, trains, finder)
            exact_routes = isolated_exact_route_combination(game, corporation, trains, finder) unless cached
            routes = better_route_combination(game, routes, exact_routes)
            prefer_cached_routes(game, corporation, trains, routes)
          rescue StandardError
            routes = sampled_route_combination(game, corporation, trains, finder)
            prefer_cached_routes(game, corporation, trains, routes)
          end

          def isolated_exact_route_combination(_game, corporation, trains, finder)
            return unless isolated_exact_routes_for_trains?(trains)

            settings = isolated_route_settings(trains)
            finder.isolated_maximum_routes(
              corporation,
              trains: trains,
              path_timeout: settings[:path_timeout],
              route_timeout: settings[:route_timeout],
              route_limit: settings[:route_limit],
              wall_timeout: settings[:wall_timeout],
            )
          end

          def isolated_route_settings(trains)
            if trains.any? { |train| long_route_train?(train) }
              {
                path_timeout: ISOLATED_LONG_ROUTE_PATH_TIMEOUT,
                route_timeout: ISOLATED_LONG_ROUTE_COMBINATION_TIMEOUT,
                route_limit: ISOLATED_LONG_ROUTE_LIMIT,
                wall_timeout: ISOLATED_LONG_ROUTE_WALL_TIMEOUT,
              }
            else
              {
                path_timeout: ISOLATED_ROUTE_PATH_TIMEOUT,
                route_timeout: ISOLATED_ROUTE_COMBINATION_TIMEOUT,
                route_limit: ISOLATED_ROUTE_LIMIT,
                wall_timeout: ISOLATED_ROUTE_WALL_TIMEOUT,
              }
            end
          end

          def isolated_exact_routes_for_trains?(trains)
            case ENV.fetch('G18_IL_BOT_EXACT_ROUTES', 'complex').downcase
            when '0', 'false', 'no', 'off'
              false
            when 'long'
              trains.any? { |train| long_route_train?(train) }
            when 'all', 'always'
              true
            else
              trains.any? { |train| exact_route_train?(train) }
            end
          end

          def exact_route_train?(train)
            return true if train.respond_to?(:name) && EXACT_ROUTE_TRAIN_NAMES.include?(train.name)

            long_route_train?(train)
          end

          def better_route_combination(game, left, right)
            return left unless right

            route_combination_revenue(game, right) > route_combination_revenue(game, left) ? right : left
          end

          def route_combination_train_count(routes)
            routes.map(&:train).uniq.size
          end

          def valid_cached_routes(game, corporation, trains)
            cached = @route_cache[corporation.id]
            return unless cached
            return unless cached[:signature] == route_cache_signature(game, corporation, trains)
            return if cached[:routes].empty?
            return if route_combination_revenue(game, cached[:routes]).negative?

            prepare_routes(cached[:routes])
          end

          def prefer_cached_routes(game, corporation, trains, routes)
            signature = route_cache_signature(game, corporation, trains)
            cached = @route_cache[corporation.id]
            current_revenue = route_combination_revenue(game, routes)

            if cached && cached[:signature] == signature
              cached_revenue = route_combination_revenue(game, cached[:routes])
              routes = cached[:routes] if cached_revenue > current_revenue
            end

            prepare_routes(routes)
            @route_cache[corporation.id] = { signature: signature, routes: routes.dup }
            routes
          end

          def route_cache_signature(game, corporation, trains)
            map = game.hexes.map { |hex| [hex.id, hex.tile.name, hex.tile.rotation] }
            tokens = corporation.tokens.map do |token|
              [token.city&.hex&.id, token.city&.index, token.status, token.type]
            end
            [game.phase.name, trains.map { |train| [train.id, train.name] }.sort, map, tokens, game.stl_permit?(corporation)]
          end

          def sampled_route_combination(game, corporation, trains, finder)
            candidates = trains.map do |train|
              [*finder.routes_for(corporation, train, limit: routes_per_train(train)), nil]
            end
            maximum_remaining = Array.new(candidates.size + 1, 0)
            (candidates.size - 1).downto(0) do |index|
              maximum_remaining[index] = maximum_remaining[index + 1] + candidates[index].first&.revenue.to_i
            end

            best_routes = []
            best_revenue = -1
            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + route_combination_timeout(trains)

            search = lambda do |index, selected, used_paths, estimated_revenue|
              return if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
              return if estimated_revenue + maximum_remaining[index] <= best_revenue

              if index == candidates.size
                revenue = route_combination_revenue(game, selected)
                if revenue > best_revenue
                  best_revenue = revenue
                  best_routes = selected.dup
                end
                return
              end

              candidates[index].each do |route|
                unless route
                  search.call(index + 1, selected, used_paths, estimated_revenue)
                  next
                end

                next if route_conflicts_with_used?(route, used_paths)

                path_ids = route.paths.map(&:id)
                search.call(
                  index + 1,
                  selected + [route],
                  used_paths.merge(path_ids.to_h { |id| [id, true] }),
                  estimated_revenue + route.revenue,
                )
              end
            end
            search.call(0, [], {}, 0)

            prepare_routes(best_routes)
          end

          def routes_per_train(train)
            long_route_train?(train) ? LONG_ROUTES_PER_TRAIN : ROUTES_PER_TRAIN
          end

          def route_combination_timeout(trains)
            trains.any? { |train| long_route_train?(train) } ? ROUTE_COMBINATION_TIMEOUT : 1
          end

          def long_route_train?(train)
            return true if train.respond_to?(:name) && LONG_ROUTE_TRAIN_NAMES.include?(train.name)
            return false unless train.respond_to?(:distance)

            distance = train.distance
            return distance.to_i >= 5 if distance.is_a?(Numeric)

            city_distance = distance.find { |row| (row['nodes'] & %w[city offboard]).any? }
            city_distance&.fetch('visit', 0).to_i >= 5
          end

          def route_conflicts_with_used?(route, used_paths)
            route.paths.any? { |path| used_paths[path.id] }
          end

          def route_combination_revenue(game, routes)
            prepare_routes(routes)
            game.routes_revenue(routes)
          rescue Engine::GameError
            -1
          end

          def prepare_routes(routes)
            routes.each do |route|
              route.routes = routes
              route.clear_cache!(only_routes: true)
              route.revenue
            end
            routes
          end
        end
      end
    end
  end
end

# rubocop:enable Layout/LineLength, Style/MultilineBlockChain, Style/UnlessLogicalOperators
