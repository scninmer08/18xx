# frozen_string_literal: true

require_relative 'route_finder'
require_relative 'policy_profile'

module Engine
  module Game
    module G18IL
      module Bot
        Decision = Struct.new(:action, :reason, keyword_init: true)

        class BaselinePolicy
          ROUTES_PER_TRAIN = 2
          ROUTE_COMBINATION_LIMIT = 100
          attr_reader :profile

          def initialize(profile: PolicyProfile.new)
            @profile = profile
          end

          def choose(game)
            step = game.round.active_step
            entity = decision_entity(game.round.current_entity, step)
            return Decision.new(reason: 'No active step or entity') if !step || !entity

            private_decision = private_ability_decision(game, entity)
            return private_decision if private_decision

            actions = step.actions(entity)
            return Decision.new(reason: 'The active entity has no actions') if actions.empty?

            decision = auction_decision(game, step, entity, actions) ||
              stock_decision(game, step, entity, actions) ||
              share_purchase_decision(game, step, entity, actions) ||
              forced_stock_sale_decision(game, step, entity, actions) ||
              conversion_decision(step, entity, actions) ||
              private_acquisition_decision(step, entity, actions) ||
              home_token_decision(game, step, entity, actions) ||
              track_decision(game, step, entity, actions) ||
              token_decision(game, step, entity, actions) ||
              share_issue_decision(game, step, entity, actions) ||
              corporate_share_sale_decision(step, entity, actions) ||
              emergency_share_sale_decision(game, step, entity, actions) ||
              train_decision(game, step, entity, actions) ||
              borrow_train_decision(step, entity, actions) ||
              route_extension_decision(game, step, entity, actions) ||
              route_decision(game, step, entity, actions) ||
              dividend_decision(step, entity, actions) ||
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
            candidates = game.hexes.flat_map do |hex|
              next [] unless step.available_hex(company, hex)

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
                [train, variant, price] if price <= owner.cash
              end
            end
            train, variant, price = candidates.max_by do |candidate_train, candidate_variant, candidate_price|
              train_candidate_score(candidate_train, candidate_variant, candidate_price, nil, owner)
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

          def conversion_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::Conversion)
            return unless actions.include?('convert')
            return unless profile[:conversion_values].fetch(entity.total_shares, 0).positive?

            Decision.new(
              action: Engine::Action::Convert.new(entity),
              reason: "Converts from #{entity.total_shares} to #{entity.total_shares == 2 ? 5 : 10} shares",
            )
          end

          def private_acquisition_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::ConversionPrivateChoice)
            return unless actions.include?('acquire_company')

            candidates = step.eligible_private_companies.map do |candidate|
              source_value = candidate.owner == entity.owner ? profile[:private_president_bonus] : 0
              [candidate, profile[:private_values].fetch(candidate.meta[:class], 0) + source_value]
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
              value = auction_value(game, entity, company)
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
              .filter_map do |candidate|
                minimum = step.min_bid(candidate)
                value = auction_value(game, entity, candidate)
                [candidate, minimum, value] if minimum <= value
              end
            company = affordable_companies.max_by do |candidate, candidate_minimum, candidate_value|
              [candidate_value - candidate_minimum, candidate_value, candidate.name]
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

          def auction_value(game, player, company)
            item_value = auction_item_value(game, player, company)
            return 0 unless item_value.positive?

            value = item_value + auction_preference(player, company)
            reserve = if concession_required?(player, company)
                        profile[:concession_cash_reserve]
                      else
                        profile[:auction_cash_reserve]
                      end
            budget = [player.cash - reserve, 0].max
            [value, budget].min - ([value, budget].min % game.class::MIN_BID_INCREMENT)
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
              concession_value(game, player, company)
            when :private
              private_value(game, player, company)
            when :share, :presidents_share
              company.value * 3 / 4
            else
              0
            end
          end

          def concession_value(game, player, company)
            corporation = game.corporation_by_id(company.sym)
            value = profile[:concession_values].fetch(company.meta[:share_count], 30)
            value += corporation.cash / 2
            value += corporation.trains.sum(&:price) / 4
            value += corporation.companies.count do |candidate|
              candidate.meta[:type] == :private
            end * profile[:attached_private_value]
            presidencies = game.corporations.count { |candidate| candidate.ipoed && candidate.owner == player }
            value -= presidencies * profile[:presidency_penalty]
            value
          end

          def private_value(game, player, company)
            eligible = game.corporations.any? do |corporation|
              corporation.owner == player && corporation.ipoed &&
                game.eligible_private_acquisitions(corporation, player).any? do |candidate|
                  candidate.meta[:class] == company.meta[:class]
                end
            end
            eligible ? profile[:private_values].fetch(company.meta[:class]) : 0
          end

          def concession_required?(player, company)
            company.meta[:type] == :concession &&
              player.companies.none? { |candidate| candidate.meta[:type] == :concession }
          end

          def stock_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BaseBuySellParShares)
            return unless actions.include?('par')

            corporation = entity.companies
              .select { |company| company.meta[:type] == :concession }
              .filter_map { |company| game.corporation_by_id(company.sym) }
              .select { |candidate| game.can_par?(candidate, entity) }
              .max_by { |candidate| concession_value(game, entity, game.company_by_id(candidate.id)) }
            return unless corporation

            par_prices = step.get_par_prices(entity, corporation)
            share_price = par_prices.max_by do |price|
              [profile[:par_values].fetch(price.price, 0), price.price]
            end
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

          def share_purchase_decision(game, step, entity, actions)
            share_step = step.is_a?(G18IL::Step::BaseBuySellParShares) ||
              step.is_a?(G18IL::Step::PostConversionShares)
            return unless share_step
            return unless actions.include?('buy_shares')
            return unless entity.player?

            bundle = purchasable_share_bundles(game, step, entity).max_by do |candidate|
              [stock_purchase_score(game, entity, candidate), candidate.corporation.name]
            end
            return unless bundle

            Decision.new(
              action: Engine::Action::BuyShares.new(entity, shares: bundle.shares),
              reason: "Buys a share of #{bundle.corporation.name} for #{bundle.price} from " \
                      "#{share_source_name(game, bundle)}",
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

          def purchasable_share_bundles(game, step, player)
            shares = game.corporations.flat_map(&:shares) + game.share_pool.shares
            shares.uniq.filter_map do |share|
              next unless share.corporation.ipoed
              next unless share.buyable

              bundle = share.to_bundle
              next if bundle.price > player.cash
              next unless step.can_buy?(player, bundle)

              bundle
            end
          end

          def stock_purchase_score(game, player, bundle)
            score = bundle.corporation.owner == player ? profile[:stock_own_corporation_bonus] : 0
            score += profile[:stock_market_bonus] if bundle.owner == game.share_pool
            score += profile[:stock_treasury_bonus] if bundle.owner == bundle.corporation
            score + (bundle.price * profile[:stock_price_weight])
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
            return unless entity.trains.empty?
            return unless entity.cash < game.depot.min_depot_price

            bundle =
              case step
              when G18IL::Step::IssueShares
                step.issuable_shares(entity).first
              when G18IL::Step::BuyTrain
                game.emergency_issuable_bundles(entity).first
              end
            return unless bundle

            Decision.new(
              action: Engine::Action::SellShares.new(
                entity,
                shares: bundle.shares,
                share_price: bundle.share_price,
              ),
              reason: "Issues #{bundle.num_shares} share#{bundle.num_shares == 1 ? '' : 's'} to fund a mandatory train",
            )
          end

          def emergency_share_sale_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BuyTrain)
            return unless entity.player?
            return unless actions.include?('sell_shares')

            bundles = game.corporations.flat_map do |corporation|
              game.bundles_for_corporation(entity, corporation)
            end
            bundle = bundles.select { |candidate| step.can_sell?(entity, candidate) }
              .min_by { |candidate| [candidate.presidents_share ? 1 : 0, candidate.price, candidate.corporation.name] }
            return unless bundle

            Decision.new(
              action: Engine::Action::SellShares.new(entity, shares: bundle.shares, percent: bundle.percent),
              reason: "Sells #{bundle.percent}% of #{bundle.corporation.name} for emergency train funding",
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

          def dividend_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::Dividend)
            return unless actions.include?('dividend')

            kind = step.dividend_types.max_by { |type| profile[:dividend_values].fetch(type, 0) }
            Decision.new(
              action: Engine::Action::Dividend.new(entity, kind: kind.to_s),
              reason: "Chooses the highest-scored dividend option, #{kind}",
            )
          end

          def planned_obsolescence_decision(step, entity, actions)
            return unless step.is_a?(G18IL::Step::ObsoleteTrain)
            return unless actions.include?('choose')

            choice = step.choices.first
            return unless choice

            Decision.new(
              action: Engine::Action::Choose.new(entity, choice: choice),
              reason: "Uses Planned Obsolescence to retain #{choice}",
            )
          end

          def train_decision(game, step, entity, actions)
            return unless step.is_a?(G18IL::Step::BuyTrain)
            return unless actions.include?('buy_train')

            candidates = step.buyable_trains(entity).flat_map do |train|
              step.train_variant_helper(train, entity).map do |variant|
                price = train_purchase_price(step, entity, train, variant)
                [train, variant, price, nil] if price
              end
            end.compact
            candidates.concat(discounted_train_candidates(game, step, entity))
            rush_delivery = step.is_a?(G18IL::Step::BuyTrainBeforeRunRoute)
            mandatory = !actions.include?('pass') && !rush_delivery
            if mandatory
              cash_funded = candidates.select { |_train, _variant, price, _exchange| price <= entity.cash }
              candidates = cash_funded unless cash_funded.empty?
            else
              spending_limit = [entity.cash - profile[:train_cash_reserve], 0].max
              candidates.select! { |_train, _variant, price, _exchange| price <= spending_limit }
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
                                                  train_candidate_score(candidate_train, candidate_variant,
                                                                        candidate_price, candidate_exchange, entity)
                                                end
                                              end
            return unless train

            score = train_candidate_score(train, variant, price, exchange, entity)
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

          def train_candidate_score(train, variant, price, exchange, entity)
            distance = variant[:distance] || train.distance
            capacity = if distance.is_a?(Numeric)
                         10
                       else
                         city_distance = distance.find { |part| (part['nodes'] & %w[city offboard]).any? }
                         [city_distance&.fetch('pay', 0).to_i, 10].min
                       end
            permanent = variant[:rusts_on].nil? && variant[:obsolete_on].nil?

            (capacity * profile[:train_capacity_weight]) +
              (permanent ? profile[:train_permanent_bonus] : 0) -
              (price / profile[:train_price_divisor]) +
              (exchange ? profile[:train_exchange_bonus] : 0) -
              (entity.trains.size * profile[:train_count_penalty])
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

              step.upgradeable_tiles(entity, hex).flat_map do |tile|
                tile.legal_rotations.filter_map do |rotation|
                  rotated_tile = tile.dup.rotate!(rotation)
                  next unless ic_line_tile_valid?(game, hex, rotated_tile)

                  cost = track_cost(hex, rotated_tile, tile_lay)
                  next if cost > entity.cash

                  score = track_candidate_score(game, hex, rotated_tile, cost, entity)
                  [hex, tile, rotation, cost, score]
                end
              end
            end
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

          def track_cost(hex, tile, tile_lay)
            action_cost = tile.color == :yellow ? tile_lay[:cost] : tile_lay[:upgrade_cost]
            terrain_cost = hex.tile.upgrades.sum(&:cost)
            border_cost = hex.tile.borders.sum { |border| border.cost || 0 }
            action_cost + terrain_cost + border_cost
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
            ic_line_bonus = ic_line_connections(game, hex, tile) * profile[:track_ic_line_weight]

            home_bonus + (neighbor_connections * profile[:track_neighbor_weight]) +
              (new_exits * profile[:track_new_exit_weight]) + (revenue * profile[:track_revenue_weight]) +
              (tile.cities.size * profile[:track_city_weight]) + ic_line_bonus - cost
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
                next if entity.trains.empty? && cost.positive? && entity.cash - cost < game.depot.min_depot_price

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
            score += profile[:token_st_louis_bonus] if game.class::STL_TOKEN_HEX.include?(hex.id)
            score += profile[:token_ic_line_bonus] if game.class::IC_LINE_CITY_HEXES.include?(hex.id)
            score += profile[:token_replacement_bonus] if slot
            score
          end

          def token_placement_cost(step, entity, slot)
            return G18IL::Step::Token::TOKEN_REPLACEMENT_COST if slot || entity.tokens.all?(&:used)

            step.available_tokens(entity).map(&:price).min || 0
          end

          def ic_line_tile_valid?(game, hex, tile)
            exits = game.class::IC_LINE_ORIENTATION[hex.id]
            return true unless exits
            if !game.ic.ipoed && game.class::IC_LINE_CITY_HEXES.include?(hex.id) &&
               game.class::IC_LINE_BROWN_TILES.include?(tile.name)
              return false
            end

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
            finder = RouteFinder.new(game)
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
              next if route_overlap?(routes)

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
