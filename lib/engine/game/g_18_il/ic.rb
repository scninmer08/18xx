# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Ic
        IC_STARTING_PRICE = 80
        IC_LINE_COUNT = 10
        IC_LINE_SUBSIDY = 20
        IC_ADDITIONAL_TOKENS = 4

        IMMOBILE_SHARE_PRICE_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Share price may not change',
          desc_detail: 'Share price may not change while IC is in receivership.'
        )
        FORCED_WITHHOLD_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'May not pay dividends',
          desc_detail: 'Must withhold earnings while IC is in receivership.'
        )
        RECEIVERSHIP_ABILITY = Ability::Description.new(
          type: 'description',
          description: 'Modified oper. turn (receivership)',
          desc_detail: 'IC only performs the "run trains", "dividend", and "buy trains" steps during ' \
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
                       'If IC is trainless and cannot afford the cheapest bank train, it receives that train and takes a loan.',
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

        def ic
          @ic ||= corporation_by_id('IC')
        end

        def ic_formation_triggered?
          @ic_formation_triggered
        end

        def post_ic_formation_stock_round?
          @post_ic_formation_stock_round
        end

        def option_cube_count(corporation)
          @option_cubes[corporation].to_i
        end

        def ic_needs_train!
          sync_ic_operating_state!
        end

        def ic_owns_train!
          sync_ic_operating_state!
        end

        def ic_line_hex?(hex)
          self.class::IC_LINE_ORIENTATION[hex.name]
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
            trigger_name = ic_formation_trigger_name(entity)
            @log << "-- The Illinois Central Railroad will form at the end of #{trigger_name}'s turn --"
            @ic_formation_triggered = true
            @ic_formation_pending = true
            @ic_trigger_entity = entity
          end
        end

        def ic_formation_trigger_name(entity)
          return entity.owner.name if entity&.company? && entity&.owner

          entity.name
        end

        def ic_formation_pending?
          @ic_formation_pending
        end

        def ic_line_connections(hex)
          return 0 unless (exits = self.class::IC_LINE_ORIENTATION[hex.name])

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
            payoff_loan(beneficiary) if beneficiary.corporation? && beneficiary.loans.any?
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

        # ---------------- IC FORMATION ----------------------
        def ic_setup
          ic.add_ability(self.class::STOCK_PURCHASE_ABILITY)
          ic.add_ability(self.class::TRAIN_BUY_ABILITY)
          ic.add_ability(self.class::TRAIN_LIMIT_ABILITY)
          ic.remove_ability(self.class::FORMATION_ABILITY)
          assign_port_permit(ic)

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
          payoff_loan(corp) if corp.loans.any?
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
          self.class::IC_LINE_CITY_HEXES.each do |hex_id|
            hex = hex_by_id(hex_id)
            @corporations.each do |corp|
              next if ic_line_corporations.include?(corp) ||
                      corp == ic ||
                      @closed_corporations.include?(corp) ||
                      frozen_corporations.include?(corp) ||
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
            payoff_loan(corporation) if corporation.loans.any?
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
          end
          # Replace the merging corporation's IC Line token with an IC token.
          ic.tokens << Token.new(ic, price: 0)
          ic_tokens = [ic.tokens.last]
          corporation_token = corporation.tokens.find { |t| self.class::IC_LINE_CITY_HEXES.include?(t&.hex&.id) }
          replace_ic_token(corporation, corporation_token, ic_tokens)

          # Transfer any remaining cash to IC.
          if corporation.cash.positive?
            amt = corporation.cash
            @log << "#{ic.name} receives #{format_currency(amt)} from #{corporation.name}"
            corporation.spend(amt, ic)
            payoff_loan(ic) if ic.loans.any?
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
          claim_ic_presidency_if_eligible!
        end

        def claim_ic_presidency_if_eligible!
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

        def add_ic_additional_tokens
          unplaced_tokens = ic.tokens.count { |token| !token.city }
          missing_tokens = IC_ADDITIONAL_TOKENS - unplaced_tokens
          return unless missing_tokens.positive?

          missing_tokens.times { ic.tokens << Token.new(ic, price: 0) }
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
          @post_ic_formation_stock_round = true
          add_ic_additional_tokens

          buy_formation_train_for_ic! if ic.trains.empty?

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

        def buy_formation_train_for_ic!
          train = @depot.min_depot_train
          return unless train

          @log << "#{ic.name} is trainless"
          ic_needs_train!

          price = train.price
          shortfall = price - ic.cash
          shortfall = 0 if shortfall.negative?
          take_loan(ic, shortfall) if shortfall.positive?

          @log << "#{ic.name} buys a #{train.name} train for #{format_currency(price)} from #{train.owner.name}"

          buy_train(ic, train, price)
          @phase.buying_train!(ic, train, train.owner)
          ic_owns_train!
        end

        def sync_ic_operating_state!
          ic.remove_ability(self.class::RECEIVERSHIP_ABILITY)
          ic.remove_ability(self.class::OPERATING_ABILITY)
          ic.remove_ability(self.class::FORCED_WITHHOLD_ABILITY)
          ic.remove_ability(self.class::IMMOBILE_SHARE_PRICE_ABILITY)
          if ic_in_receivership?
            ic.add_ability(self.class::RECEIVERSHIP_ABILITY)
            ic.add_ability(self.class::FORCED_WITHHOLD_ABILITY)
            ic.add_ability(self.class::IMMOBILE_SHARE_PRICE_ABILITY)
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

          @ic_operator = prev_owner || @players.min_by { rand }
          ic.owner = nil

          @log << "While in receivership, #{ic.name} will be operated by a random player (#{@ic_operator.name})"
        end

        def ic_in_receivership?
          ic.presidents_share.owner == ic
        end
      end
    end
  end
end
