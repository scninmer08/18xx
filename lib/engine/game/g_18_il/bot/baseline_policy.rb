# frozen_string_literal: true

require_relative 'route_finder'
require_relative 'policy_profile'

module Engine
  module Game
    module G18IL
      module Bot
        Decision = Struct.new(:action, :reason, keyword_init: true)

        class BaselinePolicy
          ROUTES_PER_TRAIN = 20
          ROUTE_COMBINATION_LIMIT = 10_000
          EXTENDED_ROUTE_PATH_TIMEOUT = 10
          EXTENDED_ROUTE_COMBINATION_TIMEOUT = 10
          EXTENDED_ROUTE_LIMIT = 2_000
          EARLY_CONCESSION_BID_CAP = 90
          LATE_CONCESSION_BID_CAP = 130
          CONCESSION_SCARCITY_PREMIUMS = {
            abundant: 0,
            modest: 5,
            tight: 15,
            scarce: 25,
          }.freeze
          CONCESSION_MIN_PLAN_BID = 10
          CONCESSION_PLAN_SCORE_DIVISOR = 3
          SURPLUS_TWO_TRAIN_PENALTY = 120
          DELAYED_IR_MIN_PAR = 120
          HIGH_VALUE_CITY_HEXES = %w[E8 E12 H3].freeze
          REVENUE_DESTINATION_VALUES = {
            'E8' => 60,
            'E12' => 60,
            'H3' => 100,
            'B17' => 100,
            'F25' => 60,
          }.freeze
          STRATEGIC_TARGET_COUNT = 2
          DESTINATION_PROGRESS_BASE = 400
          DESTINATION_PROGRESS_SCALE = 20
          TOKEN_FUTURE_VALUE_MULTIPLIER = 10
          HEALTHY_PERMANENT_FUNDING_RATIO = 0.75
          TRAIN_SUBSIDY_MINIMUM_SAVINGS = 60
          ICC_EW_DESTINATION_VALUE = 160
          ICC_NS_DESTINATION_VALUE = 120
          ENDPOINT_PAIR_TRACK_BONUS = 260
          ENDPOINT_PAIR_TRACK_PROGRESS_DIVISOR = 6
          HIGH_VALUE_TRACK_BONUS = 250
          HIGH_VALUE_ROUTE_ACCESS_MULTIPLIER = 4
          HIGH_VALUE_TOKEN_BONUS = 300
          ENDPOINT_PAIR_TOKEN_BONUS = 220
          IC_LINE_TOKEN_BONUS = 160
          STRATEGIC_ANCHOR_TOKEN_HEXES = %w[H3 E8 E12 C18].freeze
          STRATEGIC_ANCHOR_TOKEN_BONUS = 520
          STRATEGIC_ANCHOR_DENIAL_BONUS = 260
          STRATEGIC_TOKEN_PURCHASE_SCORE = 2
          TWO_SHARE_DENIAL_BONUS = 220
          TWO_SHARE_DENIAL_STOCK_BONUS = 180
          IDLE_CASH_SHARE_BONUS = 160
          WEAK_PERMANENT_ROUTE_SHARE_PENALTY = 260
          PERMANENT_ROUTE_REPAIR_MULTIPLIER = 2
          MERGE_WEAK_CORPORATION_BONUS = 260
          MERGE_IC_ANCHOR_BONUS = 180
          MERGE_TRAIN_TRANSFER_BONUS = 120
          MERGE_STRONG_INDEPENDENT_PENALTY = 380
          BOOM_CITY_UPGRADE_BONUS = 3_000
          IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_MAX_ACTIONS = 300
          IMMEDIATE_ROUTE_REVENUE_LOOKAHEAD_LIMIT = 0
          IMMEDIATE_ROUTE_REVENUE_TRACK_MULTIPLIER = 20
          ROUTE_CREATION_PROGRESS_BONUS = 600
          ROUTE_CREATION_DESTINATION_BONUS = 1_200
          IC_LINE_PROGRESS_BONUS = 300
          IC_LINE_COMPLETION_BONUS = 450
          CORPORATION_OPENING_LINK_BONUS = 6_000
          C_EI_OPENING_TRACK_COSTS = { 'G22' => 60, 'H19' => 20, 'G20' => 20, 'F21' => 20 }.freeze
          C_EI_SECOND_LAY_RESERVE_PER_HEX = 10
          FORBIDDEN_PAR_PRICES = { 'IR' => [40], 'RI' => [40] }.freeze
          PRIVATE_VALUES = {
            'AT' => 70,
            'CIB' => 15,
            'CVCC' => 45,
            'EC' => 45,
            'EM' => 35,
            'FWC' => 55,
            'GTL' => 70,
            'ICC' => 75,
            'ISBC' => 45,
            'PO' => 20,
            'RD' => 65,
            'RE' => 70,
            'SP' => 55,
            'TS' => 90,
            'USML' => 55,
            'USY' => 65,
          }.freeze
          attr_reader :profile

          def initialize(profile: PolicyProfile.new)
            @profile = profile
            @route_cache = {}
            @hex_build_distances_cache = {}
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
              president_capitalization_purchase_decision(game, step, entity, actions) ||
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
            if active_step != step && active_step&.blocking?
              return unless game.round.steps.index(step) < game.round.steps.index(active_step)
            end

            special_buy_decision(game, step, entity, step.actions(entity))
          end

          def share_premium_decision(game, step, company)
            owner = company.owner
            return unless company.sym == 'SP'
            return unless owner.trains.empty?
            return unless owner.cash < game.depot.min_depot_price

            choice = step.choices_ability(company).keys.first
            return unless choice

            Decision.new(
              action: Engine::Action::ChooseAbility.new(company, choice: choice),
              reason: "Activates #{company.name} before issuing a share",
            )
          end

          def special_track_decision(game, step, company)
            return unless step.is_a?(G18IL::Step::SpecialTrack)
            return unless step.tile_lay_available?(company)

            owner = company.owner
            ability = step.abilities(company)
            reachable_hexes = game.graph_for_entity(owner).reachable_hexes(owner) if ability.reachable
            candidates = game.hexes.flat_map do |hex|
              next [] unless step.available_hex(company, hex)
              next [] if ability.reachable && hex.id != owner.coordinates && !reachable_hexes[hex]

              step.potential_tiles(company, hex).flat_map do |tile|
                step.legal_tile_rotations(company, hex, tile).filter_map do |rotation|
                  rotated_tile = tile.dup.rotate!(rotation)
                  next unless ic_line_tile_valid?(game, hex, rotated_tile)

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
            return current_entity unless step.must_buy_train?(current_entity)

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
            permanent = cheapest_available_permanent_train(game)
            needs_conversion_for_permanent = permanent && !owns_permanent_train?(entity)
            funds_permanent = permanent && entity.cash < permanent[:price] &&
              entity.cash + projection[:total_proceeds] >= permanent[:price]
            return unless needs_conversion_for_train || needs_conversion_for_permanent || funds_permanent ||
                          profile[:conversion_values].fetch(entity.total_shares, 0).positive?

            reason = "Converts from #{entity.total_shares} to #{target_size} shares"
            if needs_conversion_for_train
              reason += ' because one share issue cannot fund its required train'
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
              .select { |candidate| auction_startable?(game, entity, candidate) }
              .filter_map do |candidate|
                minimum = step.min_bid(candidate)
                value = auction_value(game, entity, candidate, step: step)
                [candidate, minimum, value] if minimum <= value
              end
            company = random_best_by(game, affordable_companies) do |_candidate, candidate_minimum, candidate_value|
              [candidate_value - candidate_minimum, candidate_value]
            end
            return unless company

            company, minimum, value = company

            Decision.new(
              action: Engine::Action::Bid.new(entity, company: company, price: minimum),
              reason: "Opens bidding at #{minimum} for #{company.name}, valued at #{value}",
            )
          end

          def auction_target(game, step)
            step.auctioning == :turn ? game.lot_choice_proxy : step.auctioning
          end

          def auction_startable?(game, player, company)
            return private_useful_to_player?(game, player, company) if company.meta&.[](:type) == :private

            true
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
                        concession_opening_cost(game, player, company)
                      elsif company.meta[:type] == :private
                        private_auction_reserve(game, player)
                      else
                        profile[:auction_cash_reserve]
                      end
            budget = [player.cash - reserve, 0].max
            [value, budget].min - ([value, budget].min % game.class::MIN_BID_INCREMENT)
          end

          def concession_auction_value(game, player, company, raw_value, step)
            alternatives = available_concession_alternatives(game, player, step, company)
            with_plan = best_concession_opening_plan_score(game, player, alternatives, required: [company])
            without_plan = best_concession_opening_plan_score(game, player, alternatives, excluded: [company])
            plan_delta = [with_plan - without_plan, 0].max
            value = CONCESSION_MIN_PLAN_BID +
              concession_scarcity_premium(game, alternatives) +
              (plan_delta / CONCESSION_PLAN_SCORE_DIVISOR.to_f).round
            [value, raw_value].min
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
                auction_startable?(game, player, candidate)
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

          def best_concession_opening_plan_score(game, player, concessions, required: [], excluded: [])
            owned = player.companies.select { |company| company.meta&.[](:type) == :concession && !company.closed? }
            required = (owned + required).uniq
            candidates = (owned + concessions).uniq - excluded
            return 0 unless (required - candidates).empty?

            max_size = [profile[:max_concession_plan_size], candidates.size].min
            return 0 if required.size > max_size

            plans = (1..max_size).flat_map { |size| candidates.combination(size).to_a }
            plans
              .select { |plan| (required - plan).empty? }
              .select { |plan| concession_opening_plan_affordable?(game, player, plan) }
              .map { |plan| concession_opening_plan_score(game, player, plan) }
              .max.to_i
          end

          def concession_opening_plan_affordable?(game, player, plan)
            costs = plan.map { |company| concession_opening_cost(game, player, company) }
            return false if costs.any?(&:infinite?)

            costs.sum <= player.cash
          end

          def concession_opening_plan_score(game, player, plan)
            corporation_scores = plan.map { |company| concession_opening_corporation_score(game, player, company) }
            corporation_scores.sum + concession_pair_synergy_score(game, plan)
          end

          def concession_opening_corporation_score(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            return 0 unless corporation

            profile_base = profile[:concession_values].fetch(company.meta[:share_count], 30)
            assigned_private_score = corporation.companies.sum do |private_company|
              next 0 unless private_company.meta&.[](:type) == :private

              private_value_for_corporation(game, corporation, private_company)
            end
            future_private_score = future_private_fit_score(game, player, corporation)
            treasury_score = corporation.cash / 4
            train_score = corporation.trains.sum(&:price) / 8
            launch_score = concession_opening_cost(game, player, company).infinite? ? -120 : 30
            strategic_score = corporation_opening_strategic_score(game, corporation)
            denial_score = two_share_concession_denial_score(game, player, corporation)

            profile_base + treasury_score + train_score + assigned_private_score + future_private_score +
              launch_score + strategic_score + denial_score
          end

          def two_share_concession_denial_score(game, player, corporation)
            return 0 unless %w[IR NC].include?(corporation.id)

            sibling = game.corporation_by_id(corporation.id == 'IR' ? 'NC' : 'IR')
            return 0 unless sibling

            game.players.reject { |candidate| candidate == player }.any? do |candidate|
              candidate.companies.any? { |company| company.id == sibling.id } || sibling.owner == candidate
            end ? TWO_SHARE_DENIAL_BONUS : 0
          end

          def future_private_fit_score(game, player, corporation)
            privates =
              if corporation.total_shares > 2
                game.eligible_private_acquisitions(corporation, player)
              else
                development_pool_private_class(game, :B)
              end
            privates.map { |private_company| private_value_for_corporation(game, corporation, private_company) }.max.to_i / 2
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
            score -= c_ei_required_opening_capital(game, corporation) / 20 if corporation.id == 'C&EI'
            score
          end

          def concession_pair_synergy_score(game, plan)
            return 0 if plan.size < 2

            corporations = plan.filter_map { |company| game.corporation_by_id(company.sym) }
            score = 20
            score += 20 if corporations.map(&:total_shares).uniq.size > 1
            score += private_class_pair_synergy(game, corporations)
            score -= geographic_overlap_penalty(corporations)
            score
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

          def geographic_overlap_penalty(corporations)
            homes = corporations.map { |corporation| Array(corporation.coordinates).first }.compact
            return 0 if homes.size < 2

            homes.uniq.size < homes.size ? 25 : 0
          end

          def concession_bid_cap(game, company)
            corporation = game.corporation_by_id(company.sym)
            return EARLY_CONCESSION_BID_CAP unless corporation

            base = permanent_train_near?(game) || game.depot.upcoming.reject(&:reserved).first&.name.to_i >= 4 ?
              LATE_CONCESSION_BID_CAP : EARLY_CONCESSION_BID_CAP
            base += 20 if corporation.id == 'IR' && permanent_train_near?(game)
            base
          end

          def concession_opening_cost(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            return player_cannot_open_cost unless corporation

            dump_proceeds = great_share_supply?(game, player) ? 0 : forecast_presidency_dump_proceeds(game, player)
            projected_player_cash = player.cash + dump_proceeds
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

            if corporation.total_shares < 10
              # A conversion offers at least one token. Plan to buy it, one share with
              # the president's remaining cash, and issue one share. Do not assume that
              # the other bots will cooperate by buying treasury shares.
              cash -= game.class::TOKEN_COST
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

            { 2 => 0, 5 => game.class::TOKEN_COST, 10 => game.class::TOKEN_COST * 2 }.fetch(corporation.total_shares)
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

            current = ic.share_price
            projected = current
            jump_count = projected_ic_jump_count(game, ic)
            jump_prices = jump_count.times.map do
              projected = game.stock_market.find_relative_share_price(projected, ic, :right)
              projected.price
            end
            certificate_units = company.meta[:type] == :presidents_share ? 2 : 1
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
            value = profile[:concession_values].fetch(company.meta[:share_count], 30)
            value += corporation.cash / 2
            value += corporation.trains.sum(&:price) / 4
            value += corporation.companies.sum do |private_company|
              next 0 unless private_company.meta&.[](:type) == :private

              private_value_for_corporation(game, corporation, private_company)
            end
            presidencies = game.corporations.count { |candidate| candidate.ipoed && candidate.owner == player }
            value -= presidencies * profile[:presidency_penalty]
            value
          end

          def second_concession_value(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            return 0 unless corporation
            return 0 if corporation.ipoed
            return 0 if game.num_certs(player) >= game.cert_limit(player)
            return 0 if player.companies.any? { |candidate| candidate == company || candidate.id == company.id }
            return 0 if concession_opening_cost(game, player, company).infinite?

            owned = player.companies.select { |candidate| candidate.meta&.[](:type) == :concession && !candidate.closed? }
            return 0 if owned.empty?
            return 0 if owned.size >= profile[:max_concession_plan_size]

            with_plan = best_concession_opening_plan_score(game, player, [company], required: [company])
            without_plan = best_concession_opening_plan_score(game, player, [])
            delta = with_plan - without_plan
            delta += profile[:extra_concession_bailout_bonus] if second_corporation_bailout_motive?(game, player)
            return 0 if delta < profile[:extra_concession_min_delta]

            [concession_value(game, player, company), (delta / profile[:extra_concession_plan_divisor].to_f).round].min
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
            eventual_private_corporations(game, player, company).any?
          end

          def private_price_enforcement_value(company)
            base = PRIVATE_VALUES.fetch(company.id, profile[:private_values].fetch(company.meta[:class], 0))
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
            base = PRIVATE_VALUES.fetch(company.id, profile[:private_values].fetch(company.meta[:class], 0))
            base + private_context_bonus(game, corporation, company)
          end

          def private_context_bonus(game, corporation, company)
            case company.id
            when 'GTL'
              corporation.tokens.any? { |token| !token.used } ? 30 : -1_000
            when 'TS'
              permanent = cheapest_available_permanent_train(game)
              return 0 unless permanent

              discount = (permanent[:price] * 0.25).floor
              timing = train_timing_private_bonus(game, corporation, permanent[:price], discount)
              package = late_engine_private_package_bonus(game, corporation)
              owns_permanent_train?(corporation) ? (discount / 3) : discount + timing + package
            when 'RD'
              permanent = cheapest_available_permanent_train(game)
              timing = permanent ? train_timing_private_bonus(game, corporation, permanent[:price], 0) : 0
              return 60 if corporation.trains.empty?
              return 35 + timing unless owns_permanent_train?(corporation)

              0
            when 'SP'
              corporation.share_price ? corporation.share_price.price / 2 : 30
            when 'PO'
              corporation.trains.any? { |train| train.rusts_on } ? 60 : 0
            when 'RE'
              corporation.trains.size * 20
            when 'ICC'
              icc_connection_bonus(game, corporation)
            when 'USML'
              [corporation.trains.size, 1].max * 20
            when 'USY'
              corporation.tokens.any? { |token| !token.used } ? 25 : -50
            when 'AT'
              corporation.trains.empty? ? late_engine_private_package_bonus(game, corporation) / 2 : 20 + late_engine_private_package_bonus(game, corporation)
            when 'CIB'
              game.phase.name.to_i >= 8 ? 90 : 0
            when 'CVCC'
              25
            when 'EC', 'EM', 'ISBC'
              20
            when 'FWC'
              game.hex_by_id('C2').tile.color == :white ? 95 : 10
            else
              0
            end
          end

          def icc_connection_bonus(game, corporation)
            return 40 unless corporation.ipoed

            groups = connected_route_groups(game, corporation)
            east_west = (groups.include?('East') ? 1 : 0) + (groups.include?('West') ? 1 : 0)
            north_south = (groups.include?('North') ? 1 : 0) + (groups.include?('South') ? 1 : 0)
            ((2 - east_west) * 25) + ((2 - north_south) * 15)
          end

          def train_timing_private_bonus(game, corporation, train_price, discount)
            return 0 if owns_permanent_train?(corporation)

            cash = corporation.cash
            discounted_price = train_price - discount
            issue_proceeds = corporation.share_price&.price.to_i
            return 140 if cash < discounted_price && cash + issue_proceeds >= discounted_price
            return 100 if cash < train_price && cash + discount >= train_price
            return 70 if corporation.trains.empty?

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

            corporation = random_best_by(game, entity.companies
              .select { |company| company.meta[:type] == :concession }
              .filter_map { |company| game.corporation_by_id(company.sym) }
              .select { |candidate| game.can_par?(candidate, entity) }) do |candidate|
                concession_value(game, entity, game.company_by_id(candidate.id))
              end
            return unless corporation

            par_prices = bot_par_prices(step.get_par_prices(entity, corporation), corporation)
              .select { |price| launch_can_fund_train?(game, entity, corporation, price.price) }
            share_price = par_prices.max_by do |price|
              [profile[:par_values].fetch(price.price, 0), price.price]
            end
            return unless share_price
            return if delayed_launch_preferred?(game, entity, corporation, share_price.price)

            Decision.new(
              action: Engine::Action::Par.new(
                entity,
                corporation: corporation,
                share_price: share_price,
              ),
              reason: "Starts #{corporation.name} at par #{share_price.price}",
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

          def random_best_by(game, candidates)
            scored = candidates.map { |candidate| [yield(candidate), candidate] }
            best_score = scored.map(&:first).max
            tied = scored.select { |score, _candidate| score == best_score }.map(&:last)
            return tied.first if tied.size <= 1

            tied[game.rand % tied.size]
          end

          def share_purchase_decision(game, step, entity, actions)
            share_step = step.is_a?(G18IL::Step::BaseBuySellParShares) ||
              step.is_a?(G18IL::Step::PostConversionShares)
            return unless share_step
            return unless actions.include?('buy_shares')
            return unless entity.player?

            if step.is_a?(G18IL::Step::PostConversionShares)
              corporation = step.corporation
              return if corporation.owner != entity && corporation.trains.empty?
            end

            bundle = purchasable_share_bundles(game, step, entity).max_by do |candidate|
              [
                post_formation_ic_priority(game, step, entity, candidate),
                president_capitalization_priority(entity, candidate),
                c_ei_capital_priority(game, entity, candidate),
                presidency_protection_priority(game, entity, candidate),
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
                   else
                       "Buys a share of #{bundle.corporation.name} for #{bundle.price} from " \
                         "#{share_source_name(game, bundle)}"
                     end

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: reason,
            )
          end

          def forced_stock_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player?
            return unless actions.include?('sell_shares')
            return if actions.include?('pass')

            bundles = game.corporations.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation)
            end
            bundle = bundles.select { |candidate| step.can_sell?(entity, candidate) }
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
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
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
              step.can_sell?(entity, bundle) && entity.cash + bundle.price >= protection_bundle.price
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

          def available_presidency_share_bundle(game, player, corporation)
            shares = corporation.shares + game.share_pool.shares_of(corporation)
            shares.uniq.filter_map do |share|
              next if share.owner == player || share.owner&.player?

              corporate_ic = corporation == game.ic && share.owner&.corporation? &&
                share.owner.president?(player)
              next unless share.buyable || corporate_ic

              bundle = share.to_bundle
              next unless share_holding_limit_ok?(game, player, bundle)

              bundle
            end.min_by(&:price)
          end

          def presidency_worth_protecting?(game, corporation)
            !weak_stock_corporation?(game, corporation)
          end

          def president_capitalization_purchase_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless entity.player? && actions.include?('buy_shares')

            bundle = purchasable_share_bundles(game, step, entity)
              .select { |candidate| president_capitalization_priority(entity, candidate).positive? }
              .min_by { |candidate| [candidate.corporation.total_shares, candidate.price, candidate.corporation.name] }
            return unless bundle

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "The president buys a treasury share of trainless #{bundle.corporation.name} to capitalize it",
            )
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
              !bundle.presidents_share && step.can_sell?(entity, bundle) && entity.cash + bundle.price >= target.price
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

            candidates = game.corporations.reject { |corporation| corporation.owner == entity }.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation).map { |bundle| [corporation, bundle] }
            end.select do |_corporation, bundle|
              !bundle.presidents_share && step.can_sell?(entity, bundle) &&
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

            shares = corporation.shares + game.share_pool.shares_of(corporation)
            shares.uniq.filter_map do |share|
              owner = share.owner
              next if owner == player || owner&.player? || owner == corporation

              corporate_share = owner&.corporation? && owner.president?(player)
              market_share = owner == game.share_pool
              next unless market_share || corporate_share
              next unless share.buyable || corporate_share

              bundle = share.to_bundle
              next unless share_holding_limit_ok?(game, player, bundle)

              [bundle, market_share ? 0 : 1, owner&.name.to_s]
            end.sort_by { |bundle, source_priority, owner_name| [source_priority, bundle.price, owner_name] }
              .map(&:first)
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
                .select { |bundle| step.can_sell?(entity, bundle) }
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

          def distressed_stock_corporation?(game, corporation)
            corporation.ipoed && corporation.operated? && corporation.trains.empty? &&
              corporation.cash < game.depot.min_depot_price
          end

          def weak_stock_corporation?(game, corporation)
            distressed_stock_corporation?(game, corporation) || imminent_train_rust_risk?(game, corporation)
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
            (game.corporations.flat_map(&:shares) + game.share_pool.shares).uniq.any? do |share|
              corporation = share.corporation
              next false if corporation == distressed_corporation || !corporation.ipoed
              next false if share.owner == player || share.owner&.player?

              corporate_ic = corporation == game.ic && share.owner&.corporation? &&
                share.owner.president?(player)
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
            conversion_reserve = step.is_a?(G18IL::Step::BaseBuySellParShares) ?
              conversion_cash_reserve(game, player) : 0
            shares = game.corporations.flat_map(&:shares) + game.share_pool.shares
            shares.uniq.filter_map do |share|
              next unless share.corporation.ipoed
              corporate_ic = share.corporation == game.ic && share.owner&.corporation? &&
                share.owner.president?(player)
              next unless share.buyable || corporate_ic

              bundle = share.to_bundle
              next if bundle.price > player.cash
              next if player.cash - bundle.price < conversion_reserve
              next unless step.can_buy?(player, bundle)

              bundle
            end
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
            needs_permanent || needs_train_capital ||
              profile[:conversion_values].fetch(corporation.total_shares, 0).positive?
          end

          def stock_purchase_score(game, player, bundle)
            score = bundle.corporation.owner == player ? profile[:stock_own_corporation_bonus] : 0
            score += profile[:stock_market_bonus] if bundle.owner == game.share_pool
            score += profile[:stock_treasury_bonus] if bundle.owner == bundle.corporation
            score += idle_cash_share_bonus(game, player, bundle)
            score += two_share_denial_stock_bonus(game, player, bundle)
            score -= weak_permanent_route_share_penalty(game, player, bundle)
            score + (bundle.price * profile[:stock_price_weight])
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

            game.players.reject { |candidate| candidate == player }.any? do |candidate|
              candidate == corporation.owner && candidate == sibling.owner
            end ? TWO_SHARE_DENIAL_STOCK_BONUS : 0
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

            target_units = case corporation.total_shares
                           when 5, 10
                             3
                           else
                             0
                           end
            return 0 unless target_units.positive?

            current_units = player.shares_of(corporation).sum(&:percent) / corporation.share_percent
            current_units < target_units ? 1 : 0
          end

          def post_formation_ic_priority(game, step, player, bundle)
            return 0 unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return 0 unless bundle.corporation == game.ic

            priority = game.post_ic_formation_stock_round? ? 2 : 0
            priority += 2 if ic_engine_dominant?(game)
            priority += 1 if bundle.owner == game.share_pool
            priority += 1 if bundle.owner&.corporation? && bundle.owner.president?(player)
            priority
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
            return if step.is_a?(G18IL::Step::BuyTrainBeforeRunRoute)

            bundle =
              case step
              when G18IL::Step::IssueShares
                step.issuable_shares(entity).first
              when G18IL::Step::BuyTrain
                game.emergency_issuable_bundles(entity).first
            end
            return unless bundle

            mandatory_shortfall = entity.trains.empty? && entity.cash < game.depot.min_depot_price
            return if entity.share_price.price <= 40 && !mandatory_shortfall

            permanent = affordable_permanent_train_after_issue(game, entity, bundle.price) if step.is_a?(G18IL::Step::IssueShares)
            building_permanent_fund = step.is_a?(G18IL::Step::IssueShares) && !owns_permanent_train?(entity) &&
              cheapest_available_permanent_train(game)
            funding_stl_permit = cbq_needs_stl_permit_issue?(game, entity, bundle.price)
            return unless mandatory_shortfall || permanent || building_permanent_fund || funding_stl_permit

            purpose = if funding_stl_permit
                        'fund an immediately usable St. Louis permit'
                      elsif permanent
                        "fund the #{permanent[:name]} permanent train for #{permanent[:price]}"
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

            base = pending_type == :start ? starting_token_target(entity, maximum) : conversion_token_target(game, entity, maximum)
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

          def owns_permanent_train?(entity)
            entity.trains.any? { |train| train.rusts_on.nil? && train.obsolete_on.nil? }
          end

          def emergency_share_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BuyTrain)
            return unless entity.player?
            return unless actions.include?('sell_shares')

            bundles = game.corporations.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation)
            end
            bundles.select! { |candidate| step.can_sell?(entity, candidate) }
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
            permanent_withhold = dividend_train_purchase(game, step, entity, dividend_options, :withhold,
                                                         permanent: true)
            permanent_half = dividend_train_purchase(game, step, entity, dividend_options, :half, permanent: true)
            if permanent_withhold && !permanent_half
              return Decision.new(
                action: Engine::Action::Dividend.new(entity, kind: 'withhold'),
                reason: "Withholds to afford the #{permanent_withhold[:name]} permanent train",
              )
            end

            half_new_rank = dividend_train_purchase(game, step, entity, dividend_options, :half, new_rank: true)
            if half_new_rank
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

            kind = step.dividend_types.max_by { |type| profile[:dividend_values].fetch(type, 0) }
            Decision.new(
              action: Engine::Action::Dividend.new(entity, kind: kind.to_s),
              reason: "Chooses the highest-scored dividend option, #{kind}",
            )
          end

          def dividend_train_purchase(game, step, entity, dividend_options, kind, permanent: false, new_rank: false)
            return unless dividend_options[kind]

            payout_cash = projected_cash_after_dividend(step, entity, dividend_options, :payout)
            dividend_cash = projected_cash_after_dividend(step, entity, dividend_options, kind)
            dividend_train_options(game, entity)
              .select { |option| !permanent || option[:permanent] }
              .select { |option| !new_rank || !entity.trains.any? { |train| train.name == option[:name] } }
              .select { |option| payout_cash < option[:price] && dividend_cash >= option[:price] }
              .min_by { |option| option[:price] }
          end

          def projected_cash_after_dividend(step, entity, dividend_options, kind)
            option = dividend_options[kind]
            return entity.cash unless option

            entity.cash + option.fetch(:corporation, 0) + option.fetch(:divs_to_corporation, 0) +
              dividend_subsidy(step)
          end

          def dividend_subsidy(step)
            step.respond_to?(:total_subsidy) ? step.total_subsidy : 0
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
              reason: "Pays for the discounted IC share rather than selling the option cube",
            )
          end

          def merger_compensation_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::ExchangeChoicePlayer)
            return unless actions.include?('choose')

            share_choice = step.choices.find { |choice| choice.include?("share of #{game.ic.name}") }
            return unless share_choice

            cash_choice = step.choices.find { |choice| choice.start_with?('Receive ') && !choice.include?('share') }
            cash_value = cash_choice.to_s[/\$(\d+)/, 1].to_i
            share_value = game.ic.share_price&.price.to_i
            return if cash_value > share_value && !ic_engine_dominant?(game)

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: share_choice),
              reason: "Takes the IC share as merger compensation instead of cash",
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
            score += MERGE_TRAIN_TRANSFER_BONUS if corporation.trains.any? && !owns_permanent_train?(game.ic)
            score += MERGE_IC_ANCHOR_BONUS if corporation.tokens.any? do |token|
              token.used && token.hex && game.class::IC_LINE_CITY_HEXES.include?(token.hex.id)
            end
            score += MERGE_IC_ANCHOR_BONUS if ic_engine_dominant?(game)
            score -= MERGE_STRONG_INDEPENDENT_PENALTY if mature_permanent_route?(game, corporation) &&
              owns_permanent_train?(corporation)

            score
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
              bot_may_buy_train?(entity, train)
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
            mandatory = !actions.include?('pass') && !rush_delivery
            if mandatory
              cash_funded = candidates.select { |_train, _variant, price, _exchange| price <= entity.cash }
              candidates = cash_funded unless cash_funded.empty?
            else
              candidates.select! { |_train, _variant, price, _exchange| price <= entity.cash }
            end
            unless mandatory
              candidates.reject! do |_train, variant, _price, exchange|
                surplus_two_trains_after_purchase(game, entity, variant, exchange).positive?
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
              reason: "Receivership IC upgrades to the forced D train",
            )
          end

          def bot_may_buy_train?(_buyer, train)
            !train.owned_by_corporation?
          end

          def valid_train_mix_after_purchase?(game, entity, variant, exchange)
            limit = game.train_limit(entity)
            return true if limit <= 1

            trains = entity.trains.reject { |train| train == exchange }.map(&:name)
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

            (capacity * profile[:train_capacity_weight]) +
              (permanent ? profile[:train_permanent_bonus] : 0) -
              (price / profile[:train_price_divisor]) +
              (exchange ? profile[:train_exchange_bonus] : 0) -
              (entity.trains.size * profile[:train_count_penalty]) -
              surplus_two_penalty
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
                  rotated_tile = tile.dup.rotate!(rotation)
                  next unless ic_line_tile_valid?(game, hex, rotated_tile)

                  cost = track_cost(hex, rotated_tile, tile_lay)
                  next if cost > entity.cash
                  next unless preserves_train_funds?(game, entity, cost)

                  score = track_candidate_score(game, hex, rotated_tile, cost, entity)
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
              permanent_repair_bonus + boom_city_upgrade_bonus + ic_line_bonus + opening_link_bonus - cost
          end

          def permanent_route_repair_score(game, entity, *scores)
            return 0 unless entity.corporation?
            return 0 unless owns_permanent_train?(entity)
            return 0 if mature_permanent_route?(game, entity)

            scores.sum * PERMANENT_ROUTE_REPAIR_MULTIPLIER
          end

          def high_value_route_access_score(game, entity, hex, tile)
            connected_hexes = game.graph_for_entity(entity).connected_hexes(entity)
            (tile.exits).filter_map do |edge|
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

              missing_targets.any? do |target_id, _group|
                target = game.hex_by_id(target_id)
                target && neighbor.distance(target) < hex.distance(target)
              end ? ENDPOINT_PAIR_TRACK_BONUS / ENDPOINT_PAIR_TRACK_PROGRESS_DIVISOR : 0
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
            targets = (left_targets.fetch(left_group, []).map { |id| [id, left_group] } +
              right_targets.fetch(right_group, []).map { |id| [id, right_group] }) if targets.empty?
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
              targets = groups.include?('North') ? ['F25'] : groups.include?('South') ? ['G2'] : %w[G2 F25]
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
                tile = candidate.dup.rotate!(rotation)
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
            (base * (1 + (cubes * 0.5))).round
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
            return cached if cached

            finder = RouteFinder.new(game)
            routes = sampled_route_combination(game, corporation, trains, finder)
            prefer_cached_routes(game, corporation, trains, routes)
          rescue StandardError
            routes = sampled_route_combination(game, corporation, trains, finder)
            prefer_cached_routes(game, corporation, trains, routes)
          end

          def extended_route_search?(trains)
            trains.size > 2 ||
              trains.count { |train| train.name == 'D' } > 1 ||
              trains.any? { |train| train.rusts_on.nil? && train.obsolete_on.nil? }
          end

          def extended_route_combination(finder, corporation)
            finder.maximum_routes(
              corporation,
              path_timeout: EXTENDED_ROUTE_PATH_TIMEOUT,
              route_timeout: EXTENDED_ROUTE_COMBINATION_TIMEOUT,
              route_limit: EXTENDED_ROUTE_LIMIT,
            )
          end

          def better_route_combination(game, left, right)
            route_combination_revenue(game, left) >= route_combination_revenue(game, right) ? left : right
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
              [nil, *finder.routes_for(corporation, train, limit: ROUTES_PER_TRAIN)]
            end
            combinations = 0
            best_routes = []
            best_revenue = -1

            candidates.first.product(*candidates.drop(1)) do |combination|
              combinations += 1
              break if combinations > ROUTE_COMBINATION_LIMIT

              routes = combination.compact
              revenue = route_combination_revenue(game, routes)
              next if revenue <= best_revenue

              best_revenue = revenue
              best_routes = routes.dup
            end

            prepare_routes(best_routes)
          end

          def route_overlap?(routes)
            paths = {}
            stops = {}
            routes.any? do |route|
              route.connection_data.any? do |segment|
                segment_paths = segment[:chain][:paths]
                segment_stops = [segment[:left], segment[:right]].compact
                overlap = segment_paths.any? { |path| paths[path.id] } || segment_stops.any? { |stop| stops[stop] }
                segment_paths.each { |path| paths[path.id] = true }
                segment_stops.each { |stop| stops[stop] = true }
                overlap
              end
            end
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
