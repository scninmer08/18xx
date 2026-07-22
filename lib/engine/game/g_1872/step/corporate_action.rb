# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'

module Engine
  module Game
    module G1872
      module Step
        class CorporateAction < Engine::Step::BuySellParShares
          ACTION_BUY_SHARE = 'buy_share'
          ACTION_SELL_SHARES = 'sell_shares'
          ACTION_START_CORPORATION = 'start_corporation'
          ACTION_ACQUIRE_CORPORATION = 'acquire_corporation'
          ACTION_MERGE_CORPORATION = 'merge_corporation'
          ACTION_SKIP = 'skip'

          def setup
            super
            @corporate_action = nil
            @start_stage = nil
            @new_corporation = nil
            @sponsor = nil
            @selected_land_grant = nil
            @acquisition_target = nil
            @merger_price_options = nil
            @target_tokens = nil
          end

          def description
            return 'Buy a Share' if @corporate_action == ACTION_BUY_SHARE
            return 'Sell Shares' if @corporate_action == ACTION_SELL_SHARES
            return 'Start a New Corporation' if @corporate_action == ACTION_START_CORPORATION
            return 'Acquire a Corporation' if @corporate_action == ACTION_ACQUIRE_CORPORATION
            return 'Merge Corporations' if @corporate_action == ACTION_MERGE_CORPORATION

            'Corporate Action'
          end

          def issue_text(_entity)
            'Sell Shares:'
          end

          def actions(entity)
            return [] if entity != current_entity || !entity.corporation?
            return [] unless corporate_actions_available?(entity) || @corporate_action

            if @corporate_action == ACTION_SELL_SHARES
              actions = []
              actions << 'sell_shares' unless sellable_bundles(entity, nil).empty?
              actions << 'pass'
              return actions
            end

            return ['buy_shares'] if @corporate_action == ACTION_BUY_SHARE && can_buy_one_share?(entity)

            if @corporate_action == ACTION_START_CORPORATION
              return ['choose'] if @start_stage == :land_grant
              return ['lay_tile'] if @start_stage == :land_grant_upgrade
              return ['par'] if @start_stage == :par
              return share_purchase_actions(entity) if @start_stage == :shares

              return ['choose']
            end
            if @corporate_action == ACTION_ACQUIRE_CORPORATION
              return %w[remove_token choose] if @start_stage == :replace_token

              return ['choose']
            end
            return ['choose'] if @corporate_action == ACTION_MERGE_CORPORATION

            choices.empty? ? [] : ['choose']
          end

          def auto_actions(entity)
            programmed = super
            return programmed if programmed&.any?
            return [] unless corporate_actions_available?(entity) || @corporate_action

            if @corporate_action == ACTION_START_CORPORATION && @start_stage == :shares && entity == @sponsor
              return [Engine::Action::Pass.new(entity)] unless child_share_buy_available?(entity)
            end

            return super if @corporate_action || @start_stage

            return [Engine::Action::Choose.new(entity, choice: ACTION_SKIP)] if action_choices.keys == [ACTION_SKIP]

            []
          end

          def choice_name
            case @start_stage
            when :acquisition_target
              'Choose a corporation to acquire'
            when :acquisition_price
              "Choose the acquisition share price for #{current_entity.name} and #{@acquisition_target.name}"
            when :merger_target
              'Choose a related corporation to merge'
            when :merger_price
              "Choose the merger share price for #{current_entity.name} and #{@acquisition_target.name}"
            when :land_grant
              "Choose a land grant for #{@new_corporation.name}"
            when :land_grant_upgrade
              "Lay an upgrade on #{@selected_land_grant.name} for #{@new_corporation.name}'s home station"
            when :replace_token
              "Select #{@acquisition_target.name} stations to replace with #{current_entity.name} markers"
            else
              'Choose a corporate action'
            end
          end

          def render_choices?
            @start_stage != :land_grant
          end

          def choices
            return acquisition_target_choices if @start_stage == :acquisition_target
            return merger_price_choices if @start_stage == :acquisition_price
            return merger_target_choices if @start_stage == :merger_target
            return merger_price_choices if @start_stage == :merger_price
            return land_grant_choices if @start_stage == :land_grant
            return replacement_choices if @start_stage == :replace_token

            action_choices
          end

          def process_choose(action)
            raise GameError, 'That corporate action is not available' unless choices.key?(action.choice)

            return choose_corporate_action(action) unless @corporate_action

            case @start_stage
            when :land_grant
              choose_land_grant(action.entity, action.choice)
            when :acquisition_target
              begin_acquisition(action.entity, action.choice)
            when :acquisition_price
              complete_acquisition_with_price(action.entity, action.choice)
            when :merger_target
              begin_merger(action.entity, action.choice)
            when :merger_price
              complete_merger(action.entity, action.choice)
            when :replace_token
              process_token_replacement(action.entity, action.choice)
            end
          end

          def process_sell_shares(action)
            raise GameError, 'That share bundle cannot be sold' unless can_sell?(action.entity, action.bundle)

            movement = action.bundle.owner == action.bundle.corporation ? :down_share : nil
            @game.sell_shares_and_change_price(
              action.bundle,
              allow_president_change: false,
              movement: movement,
            )
          end

          def process_par(action)
            raise GameError, 'That shell cannot be parred' unless can_par_shell?(action.corporation, action.entity)
            raise GameError, 'That par price is unavailable' unless get_par_prices(action.entity, action.corporation)
              .include?(action.share_price)

            corporation = action.corporation
            @game.stock_market.set_par(corporation, action.share_price)
            president = corporation.presidents_share
            @game.share_pool.transfer_shares(
              president.to_bundle,
              @sponsor,
              spender: @sponsor,
              receiver: corporation,
              price: action.share_price.price * 2,
              allow_president_change: false,
              corporate_transfer: true,
            )
            corporation.owner = @sponsor
            corporation.ipoed = true
            @game.after_par(corporation)
            @round.current_actions << action
            @start_stage = :shares
            @log << "#{@sponsor.name} pars #{corporation.name} at #{@game.format_currency(action.share_price.price)} "\
                    "and buys its 20% president's certificate"
          end

          def process_buy_shares(action)
            raise GameError, 'That share cannot be purchased' unless can_buy?(action.entity, action.bundle)

            if @corporate_action == ACTION_BUY_SHARE
              buy_corporate_share(action)
              pass!
              return
            end

            @game.share_pool.transfer_shares(
              action.bundle,
              @sponsor,
              spender: @sponsor,
              receiver: @new_corporation,
              price: action.bundle.price,
              allow_president_change: false,
              corporate_transfer: true,
            )
            @round.current_actions << action
            @log << "#{@sponsor.name} buys a 10% share of #{@new_corporation.name} for "\
                    "#{@game.format_currency(action.bundle.price)}"
            finish_child_share_buying! unless child_share_buy_available?(@sponsor)
          end

          def process_lay_tile(action)
            raise GameError, 'No land grant home upgrade is pending' unless @start_stage == :land_grant_upgrade
            raise GameError, 'That corporation cannot lay this land grant home upgrade' unless action.entity == @sponsor
            raise GameError, 'That hex is not the selected land grant' unless action.hex == selected_land_grant_hex
            raise GameError, 'That tile cannot be used for this land grant home' unless
              potential_tiles(action.entity, action.hex).any? { |tile| tile.name == action.tile.name }

            @game.lay_land_grant_home_upgrade!(action.hex, action.tile, action.rotation)
            place_land_grant_home_and_continue_to_par!
          end

          def process_pass(_action)
            if @corporate_action == ACTION_START_CORPORATION && @start_stage == :shares
              finish_child_share_buying!
              return
            end

            super
          end

          # This is an operating-round action. Do not use the stock-round pass
          # bookkeeping inherited with BuySellParShares.
          def pass!
            @passed = true
          end

          def pass_description
            return 'Done (Buy)' if @start_stage == :shares
            return 'Done (Sell Shares)' if @corporate_action == ACTION_SELL_SHARES

            'Pass'
          end

          def issuable_shares(entity)
            return sellable_corporate_share_bundles(entity) if @corporate_action == ACTION_SELL_SHARES

            @game.issuable_shares(entity)
          end

          def sellable_bundles(entity, corporation)
            return [] unless @corporate_action == ACTION_SELL_SHARES
            return [] unless entity == current_entity

            bundles = sellable_corporate_share_bundles(entity)
            corporation ? bundles.select { |bundle| bundle.corporation == corporation } : bundles
          end

          def visible_corporations
            if @corporate_action == ACTION_BUY_SHARE
              return buyable_one_share_bundles
                .select { |bundle| can_buy_one_share_bundle?(current_entity, bundle) }
                .map(&:corporation)
                .uniq
                .sort
            end

            if @corporate_action == ACTION_SELL_SHARES
              return sellable_corporate_share_bundles(current_entity).map(&:corporation).uniq.sort
            end

            [@new_corporation].compact
          end

          def show_other
            return unless @corporate_action == ACTION_START_CORPORATION
            return unless @new_corporation&.ipoed

            @new_corporation
          end

          def corporate_issue_shares?
            false
          end

          def ipo_type(_corporation)
            :par
          end

          def get_par_prices(entity, corporation)
            return [] unless can_par_shell?(corporation, entity)

            @game.stock_market.par_prices
              .reject { |price| @game.par_price_gated_until_phase_3?(price) }
              .select { |price| entity.cash >= price.price * 2 }
          end

          def can_par_shell?(corporation, entity)
            @corporate_action == ACTION_START_CORPORATION && @start_stage == :par &&
              corporation == @new_corporation && entity == @sponsor && !corporation.ipoed
          end

          def can_buy?(entity, bundle)
            return can_buy_one_share_bundle?(entity, bundle) if @corporate_action == ACTION_BUY_SHARE

            return false if @corporate_action != ACTION_START_CORPORATION || @start_stage != :shares
            return false if entity != @sponsor || bundle&.corporation != @new_corporation
            return false if bundle.owner != @new_corporation || bundle.percent != 10 || !bundle.buyable
            return false if additional_shares_bought >= 2

            entity.cash >= bundle.price
          end

          def can_sell?(entity, bundle)
            return can_sell_corporate_share_bundle?(entity, bundle) if @corporate_action == ACTION_SELL_SHARES

            false
          end

          def available_hex(entity, hex)
            return false unless entity == current_entity

            if @corporate_action == ACTION_START_CORPORATION && @start_stage == :land_grant
              return land_grant_choices.key?(hex.id)
            end

            if @corporate_action == ACTION_START_CORPORATION && @start_stage == :land_grant_upgrade
              return hex == selected_land_grant_hex && potential_tiles(entity, hex).any?
            end

            if @corporate_action == ACTION_ACQUIRE_CORPORATION && @start_stage == :replace_token
              return @target_tokens.any? { |token| token.hex == hex && replacement_available?(entity, token) }
            end

            false
          end

          def potential_tiles(entity_or_entities, hex)
            return [] unless @corporate_action == ACTION_START_CORPORATION
            return [] unless @start_stage == :land_grant_upgrade
            return [] unless Array(entity_or_entities).include?(@sponsor)
            return [] unless hex == selected_land_grant_hex

            @game.land_grant_home_upgrade_tiles(hex)
          end

          def can_replace_token?(entity, token)
            return false unless token

            if @corporate_action == ACTION_ACQUIRE_CORPORATION && @start_stage == :replace_token
              return @target_tokens.include?(token) && replacement_available?(entity, token)
            end

            false
          end

          def process_remove_token(action)
            token = token_at_slot(action.city, action.slot)

            if @corporate_action == ACTION_ACQUIRE_CORPORATION && @start_stage == :replace_token
              replace_acquired_station(action.entity, token)
              return
            end

            raise GameError, 'That station cannot become the child corporation home'
          end

          def action_choices
            return {} unless corporate_actions_available?(current_entity)

            choices = {}
            choices[ACTION_BUY_SHARE] = 'Buy a Share' if can_buy_one_share?(current_entity)
            choices[ACTION_SELL_SHARES] = 'Sell Shares' unless sellable_corporate_share_bundles(current_entity).empty?
            choices[ACTION_START_CORPORATION] = 'Start a New Corporation' if can_start_corporation?(current_entity)
            choices[ACTION_MERGE_CORPORATION] = 'Merge' unless merger_targets(current_entity).empty?
            choices[ACTION_ACQUIRE_CORPORATION] = 'Acquire a Corporation' if @game.hostile_takeover_variant? &&
              !acquisition_targets(current_entity).empty?
            choices[ACTION_SKIP] = 'Pass'
            choices
          end

          def choose_corporate_action(action)
            if action.choice == ACTION_SKIP
              @log << "#{action.entity.name} passes its corporate action"
              pass!
              return
            end

            @corporate_action = action.choice
            case action.choice
            when ACTION_BUY_SHARE
              @log << "#{action.entity.name} chooses to buy one share"
            when ACTION_SELL_SHARES
              @log << "#{action.entity.name} chooses to sell shares"
            when ACTION_ACQUIRE_CORPORATION
              @start_stage = :acquisition_target
              @log << "#{action.entity.name} chooses to acquire a corporation"
            when ACTION_MERGE_CORPORATION
              @start_stage = :merger_target
              @log << "#{action.entity.name} chooses to merge corporations"
            else
              raise GameError, "#{action.entity.name} already has an isolated shell" if
                @game.has_isolated_shell_descendant?(action.entity)

              @sponsor = action.entity
              @new_corporation = unused_corporations.first
              @game.assign_shell_identity(@new_corporation, @sponsor)
              @start_stage = :land_grant
              @log << "#{action.entity.name} chooses to start #{@new_corporation.name}"
            end
          end

          def unused_corporations
            @game.available_shells.select { |corporation| corporation.presidents_share.buyable }
          end

          def can_buy_one_share?(entity)
            return false unless entity&.corporation?
            return false unless corporate_actions_available?(entity)

            buyable_one_share_bundles.any? { |bundle| can_buy_one_share_bundle?(entity, bundle) }
          end

          def buyable_one_share_bundles
            market = @game.share_pool.shares.select { |share| buyable_one_share_corporation?(share.corporation) }.map(&:to_bundle)
            market
          end

          def buyable_one_share_corporation?(corporation)
            corporation&.ipoed && corporation.floated? && !corporation.closed? && corporation.share_price
          end

          def can_buy_one_share_bundle?(entity, bundle)
            return false if !bundle&.buyable || bundle.percent != 10
            return false unless bundle.owner == @game.share_pool
            return false unless @game.corporation_may_own_shares?(entity, bundle.corporation)
            return false if entity.cash < bundle.price

            can_gain?(entity, bundle)
          end

          def sellable_corporate_share_bundles(entity)
            return [] unless entity&.corporation?

            entity.shares
              .reject(&:president)
              .select do |share|
                share.percent == 10 &&
                  share.buyable &&
                  @game.corporation_may_own_shares?(entity, share.corporation) &&
                  buyable_one_share_corporation?(share.corporation) &&
                  @game.corporation_share_sellable?(share.corporation)
              end
              .group_by(&:corporation)
              .flat_map do |corporation, shares|
                (1..shares.size).map do |count|
                  ShareBundle.new(shares.take(count)).tap { |bundle| bundle.share_price = corporation.share_price.price }
                end
              end
              .select { |bundle| can_sell_corporate_share_bundle?(entity, bundle) }
          end

          def can_sell_corporate_share_bundle?(entity, bundle)
            return false if !bundle || bundle.owner != entity
            return false if bundle.shares.empty? || bundle.shares.any?(&:president)
            return false unless bundle.shares.all?(&:buyable)
            return false unless bundle.percent.positive? && (bundle.percent % 10).zero?
            return false unless buyable_one_share_corporation?(bundle.corporation)
            return false unless @game.corporation_may_own_shares?(entity, bundle.corporation)
            return false unless @game.corporation_share_sellable?(bundle.corporation)
            return false unless @game.share_pool.fit_in_bank?(bundle)

            true
          end

          def buy_corporate_share(action)
            bundle = action.bundle
            receiver = bundle.owner == @game.share_pool ? @game.bank : bundle.corporation
            source = bundle.owner == @game.share_pool ? 'the market' : "#{bundle.corporation.name}'s treasury"
            price = bundle.price
            @game.share_pool.transfer_shares(
              bundle,
              action.entity,
              spender: action.entity,
              receiver: receiver,
              price: price,
              allow_president_change: false,
              corporate_transfer: true,
            )
            @log << "#{action.entity.name} buys a 10% share of #{bundle.corporation.name} from #{source} for "\
                    "#{@game.format_currency(price)}"
          end

          def token_at_slot(city, slot)
            normal_slots = city.tokens.size
            return city.tokens[slot] if slot < normal_slots

            city.extra_tokens[slot - normal_slots]
          end

          def share_purchase_actions(entity)
            actions = []
            actions << 'buy_shares' if child_share_buy_available?(entity)
            actions << 'pass'
            actions
          end

          def child_share_buy_available?(entity)
            return false if additional_shares_bought >= 2

            available_child_shares.any? { |share| can_buy?(entity, share.to_bundle) }
          end

          def can_start_corporation?(sponsor)
            return false unless corporate_actions_available?(sponsor)
            return false if @game.has_isolated_shell_descendant?(sponsor)

            minimum_par = @game.stock_market.par_prices.map(&:price).min
            controller = @game.acting_for_entity(sponsor)
            unused_corporations.any? &&
              controller&.player? &&
              sponsor.cash >= minimum_par * 2 &&
              available_land_grants(sponsor).any?
          end

          def available_land_grants(sponsor)
            controller = @game.acting_for_entity(sponsor)
            return [] unless controller&.player?

            @game.corporation_land_grants(sponsor).select do |land_grant|
              @game.usable_land_grant?(land_grant, sponsor) &&
                @game.genealogy_land_grant_territory_available?(sponsor, land_grant)
            end
          end

          def land_grant_choices
            available_land_grants(@sponsor).to_h do |land_grant|
              [@game.land_grant_hex_id(land_grant), land_grant.name]
            end
          end

          def choose_land_grant(entity, hex_id)
            land_grant = available_land_grants(entity).find { |grant| @game.land_grant_hex_id(grant) == hex_id }
            raise GameError, 'That land grant cannot be used to start this corporation' unless land_grant

            @selected_land_grant = land_grant
            @log << "#{entity.name} selects #{land_grant.name} as #{@new_corporation.name}'s land grant"

            if @game.land_grant_home_city_available?(selected_land_grant_hex)
              place_land_grant_home_and_continue_to_par!
            else
              @start_stage = :land_grant_upgrade
              @log << "#{@selected_land_grant.name} must be upgraded before #{@new_corporation.name}'s home station "\
                      'can be placed'
            end
          end

          def available_child_shares
            @new_corporation.shares.select do |share|
              share.owner == @new_corporation && !share.president && share.buyable
            end
          end

          def additional_shares_bought
            [(@sponsor.percent_of(@new_corporation) - 20) / 10, 0].max
          end

          def start_corporation
            validate_sponsorship!

            corporation = @new_corporation
            corporation.floated = true
            true
          end

          def finish_child_share_buying!
            home_city = @new_corporation.tokens.find(&:used)&.city
            raise GameError, "#{@new_corporation.name}'s home station has not been placed" unless home_city

            @game.purchase_starting_tokens(@new_corporation, home_city: home_city)
            @log << "#{@sponsor.name} finishes buying shares of #{@new_corporation.name}"
            pass! if start_corporation
          end

          def validate_sponsorship!
            raise GameError, 'The corporation has not been parred' unless @new_corporation.ipoed
            raise GameError, 'A land grant must be selected for the new corporation' unless @selected_land_grant
            raise GameError, "#{@new_corporation.name}'s home station has not been placed" unless
              @new_corporation.tokens.any?(&:used)
          end

          def selected_land_grant_hex
            @game.hex_by_id(@game.land_grant_hex_id(@selected_land_grant))
          end

          def place_land_grant_home_and_continue_to_par!
            @game.place_shell_land_grant_home(
              @new_corporation,
              @sponsor,
              @selected_land_grant,
            )
            @start_stage = :par
          end

          def acquisition_targets(acquirer)
            @game.corporations.select do |target|
              target != acquirer && target.type != :shell && target.floated? && acquisition_eligible?(acquirer, target)
            end
          end

          def acquisition_target_choices
            acquisition_targets(current_entity).to_h { |corporation| [corporation.id, corporation.name] }
          end

          def merger_targets(entity)
            return [] unless corporate_actions_available?(entity)

            @game.corporations.select do |target|
              next false if target == entity || target.closed? || !target.floated?
              next false unless target.operated?
              next false unless @game.same_genealogy?(entity, target)
              next false if @game.corporation_ancestor?(entity, target)
              next false unless merger_presidency_possible?(entity, target)

              merger_connected?(entity, target)
            end
          end

          def merger_target_choices
            merger_targets(current_entity).to_h do |target|
              [target.id, "#{current_entity.name} absorbs #{target.name}"]
            end
          end

          def merger_connected?(survivor, closing)
            connected_to_target?(@game.token_corporation(survivor), closing)
          end

          def corporate_actions_available?(entity)
            entity&.corporation? && !@game.isolated_shell?(entity) && @game.phase.available?('3') && entity.operated?
          end

          def begin_merger(entity, corporation_id)
            target = @game.corporation_by_id(corporation_id)
            raise GameError, 'That corporation cannot be merged' unless merger_targets(entity).include?(target)

            @log << "#{entity.name} begins merging with #{target.name}"
            @acquisition_target = target
            @merger_price_options = merger_share_prices(entity, target)
            if @merger_price_options.one?
              finalize_acquisition(entity, target, hostile: false, action_name: 'merger', new_price: @merger_price_options.first)
            else
              @start_stage = :merger_price
              return
            end

            pass!
          end

          def merger_price_choices
            @merger_price_options.to_h do |price|
              [price.id, @game.format_currency(price.price)]
            end
          end

          def complete_merger(entity, share_price_id)
            share_price = @merger_price_options.find { |price| price.id == share_price_id }
            raise GameError, 'That merger share price is not available' unless share_price

            finalize_acquisition(entity, @acquisition_target, hostile: false, action_name: 'merger', new_price: share_price)
            pass!
          end

          def acquisition_eligible?(acquirer, target)
            return false if target.type == :shell

            player = @game.acting_for_entity(acquirer)
            return false unless player&.player?
            return false unless acquirer.owner == player
            return false unless acquirer.tokens.any? { |token| !token.used }
            return false unless connected_to_target?(acquirer, target)
            return false if target_home_conflicts?(acquirer, target)

            player_units = share_units(player, acquirer, target)
            return false if player.percent_of(target) < 10 || player_units < 4

            target_president = target.owner
            return true if target_president == player

            player_units > share_units(target_president, acquirer, target)
          end

          def connected_to_target?(acquirer, target)
            connected = @game.token_graph_for_entity(acquirer).connected_nodes(acquirer).keys
            target.tokens.select(&:used).any? { |token| token.city && connected.include?(token.city) }
          end

          def target_home_conflicts?(acquirer, target)
            home = target.tokens.first
            !home&.used || acquirer.tokens.any? { |token| token.used && token.hex == home.hex }
          end

          def share_units(holder, acquirer, target)
            return 0 unless holder

            (holder.percent_of(acquirer) + holder.percent_of(target)) / 10
          end

          def begin_acquisition(acquirer, corporation_id)
            target = @game.corporation_by_id(corporation_id)
            raise GameError, 'That corporation cannot be acquired' unless acquisition_targets(acquirer).include?(target)

            @acquisition_target = target
            home = target.tokens.first
            others = target.tokens.select(&:used).reject { |token| token == home }
            @log << "#{acquirer.name} begins acquiring #{target.name}"
            replace_home_station!(acquirer, home)
            @target_tokens = others
            @start_stage = :replace_token
            prepare_target_tokens(acquirer)
          end

          def replace_home_station!(acquirer, home)
            raise GameError, 'The target corporation has no home station to replace' unless home&.used
            raise GameError, 'The target corporation has no home city to replace' unless home.city
            raise GameError, 'The acquiring corporation has no available station marker' unless
              replacement_available?(acquirer, home)

            city = home.city
            replacement = acquirer.tokens.find { |token| !token.used }
            home.swap!(replacement, check_tokenable: false)
            @log << "#{acquirer.name} replaces #{@acquisition_target.name}'s home station at #{city.hex.id}"
          end

          def replacement_choices
            { 'done' => 'Done' }
          end

          def replacement_available?(acquirer, target_token)
            target_token&.city && acquirer.tokens.any? { |token| !token.used } &&
              acquirer.tokens.none? { |token| token.used && token.hex == target_token.hex }
          end

          def process_token_replacement(acquirer, choice)
            raise GameError, 'That acquisition choice is not available' unless choice == 'done'

            remove_remaining_target_tokens('the acquiring corporation declines to replace it')
            complete_acquisition(acquirer)
          end

          def replace_acquired_station(acquirer, target_token)
            raise GameError, 'That target station cannot be replaced' unless can_replace_token?(acquirer, target_token)

            hex_id = target_token.hex.id
            replacement = acquirer.tokens.find { |token| !token.used }
            target_token.swap!(replacement, check_tokenable: false)
            @target_tokens.delete(target_token)
            @log << "#{acquirer.name} replaces #{@acquisition_target.name}'s station at #{hex_id}"
            prepare_target_tokens(acquirer)
          end

          def prepare_target_tokens(acquirer)
            colocated, @target_tokens = @target_tokens.partition do |token|
              acquirer.tokens.any? { |candidate| candidate.used && candidate.hex == token.hex }
            end
            colocated.each do |token|
              hex_id = token.hex.id
              token.remove!
              @log << "#{@acquisition_target.name}'s station at #{hex_id} is removed because "\
                      "#{acquirer.name} already has a station in that hex"
            end

            if acquirer.tokens.none? { |token| !token.used }
              remove_remaining_target_tokens("#{acquirer.name} has no available station markers")
            end

            complete_acquisition(acquirer) if @target_tokens.empty?
          end

          def remove_remaining_target_tokens(reason)
            @target_tokens.each do |token|
              hex_id = token.hex.id
              token.remove!
              @log << "#{@acquisition_target.name}'s station at #{hex_id} is removed because #{reason}"
            end
            @target_tokens.clear
          end

          def complete_acquisition(acquirer)
            @merger_price_options = merger_share_prices(acquirer, @acquisition_target)
            if @merger_price_options.one?
              finalize_acquisition(acquirer, @acquisition_target, new_price: @merger_price_options.first)
              pass!
            else
              @start_stage = :acquisition_price
            end
          end

          def complete_acquisition_with_price(acquirer, share_price_id)
            share_price = @merger_price_options.find { |price| price.id == share_price_id }
            raise GameError, 'That acquisition share price is not available' unless share_price

            finalize_acquisition(acquirer, @acquisition_target, new_price: share_price)
            pass!
          end

          def finalize_acquisition(acquirer, target, hostile: true, action_name: 'acquisition', new_price: nil)
            new_price ||= merger_share_prices(acquirer, target).first
            move_acquisition_share_price(acquirer, new_price)
            exchange_acquisition_shares(acquirer, target, new_price, hostile: hostile)
            transfer_acquisition_assets(acquirer, target)
            @game.reparent_shell_family(target, acquirer)
            sell_illegal_corporate_holdings(acquirer)
            @game.close_corporation(target)
            @game.graph.clear_graph_for_all
            @start_stage = nil
            @merger_price_options = nil
            @log << "#{acquirer.name} completes its #{action_name} with #{target.name}"
          end

          def sell_illegal_corporate_holdings(corporation)
            corporation.shares.group_by(&:corporation).each do |share_corporation, shares|
              next if @game.corporation_may_own_shares?(corporation, share_corporation)

              bundle = ShareBundle.new(shares)
              bundle.share_price = share_corporation.share_price.price
              @game.sell_shares_and_change_price(
                bundle,
                allow_president_change: !@game.sponsored_corporation?(share_corporation),
              )
            end
          end

          def merger_share_prices(acquirer, target)
            acquirer_price = acquirer.share_price
            target_price = target.share_price

            if acquirer_price.price > 250 && target_price.price > 250
              return acquirer_price.price == target_price.price ? [acquirer_price] : [acquirer_price, target_price].sort_by(&:price)
            end

            return [acquirer_price] if acquirer_price.price > 250
            return [target_price] if target_price.price > 250

            [rightmost_share_price_below([acquirer_price.price + target_price.price, 250].min)]
          end

          def rightmost_share_price_below(value)
            best_col = -1
            best_price = nil
            @game.stock_market.market.each do |row|
              row_col = -1
              row_best = nil
              row.each_with_index do |share_price, col|
                next unless share_price
                next unless share_price.price < value
                next if row_best && share_price.price <= row_best.price

                row_col = col
                row_best = share_price
              end
              next unless row_best && row_col > best_col

              best_col = row_col
              best_price = row_best
            end
            raise GameError, "No merger share price is available below #{value}" unless best_price

            best_price
          end

          def exchange_acquisition_shares(acquirer, target, new_price, hostile:)
            units = acquisition_units(acquirer, target)
            units, excess_holders = adjusted_units_for_exchange(units)

            acting_player = @game.acting_for_entity(acquirer)
            entitlements = units.transform_values { |count| count / 2 }
            president_holder = if hostile
                                 raise GameError, 'The acting player cannot become president after the acquisition' if
                                   entitlements.fetch(acting_player, 0) < 2

                                 acting_player
                               else
                                 merger_president_holder(entitlements, acquirer)
                               end
            raise GameError, 'The acquisition exchange does not total 100%' unless entitlements.values.sum == 10

            excess_holders.each do |holder|
              payment = (new_price.price / 2).floor(0)
              @game.bank.spend(payment, holder)
              @log << "#{holder.name} sells excess share to the market for #{@game.format_currency(payment)}"
            end

            reset_surviving_shares(acquirer)
            transfer_share(acquirer.presidents_share, president_holder)
            entitlements[president_holder] -= 2

            common_shares = @game.shares_for_corporation(acquirer).reject(&:president)
            entitlements.each do |holder, count|
              count.times do
                share = common_shares.shift
                raise GameError, 'Not enough surviving shares for the acquisition exchange' unless share

                transfer_share(share, holder)
              end
            end
            raise GameError, 'The acquisition exchange left unused surviving shares' unless common_shares.empty?

            acquirer.owner = president_holder
          end

          def acquisition_units(acquirer, target)
            units = Hash.new(0)
            [acquirer, target].each do |corporation|
              @game.shares_for_corporation(corporation).each do |share|
                location = share.owner == corporation ? acquirer : share.owner
                units[location] += share.percent / 10
              end
            end
            units
          end

          def adjusted_units_for_exchange(units)
            market = @game.share_pool
            adjusted = Hash.new(0)
            units.each { |holder, count| adjusted[holder] = count }
            adjusted[market] += 0
            excess_holders = []

            adjusted.each do |holder, count|
              next if holder == market || count.even?

              adjusted[holder] -= 1
              adjusted[market] += 1
              excess_holders << holder
            end

            [adjusted, excess_holders]
          end

          def merger_presidency_possible?(acquirer, target)
            units, = adjusted_units_for_exchange(acquisition_units(acquirer, target))
            entitlements = units.transform_values { |count| count / 2 }
            return false unless entitlements.values.sum == 10

            merger_president_holder(entitlements, acquirer)
            true
          rescue GameError
            false
          end

          def merger_president_holder(entitlements, acquirer)
            current_president = acquirer.owner
            if current_president && ![@game.share_pool, @game.bank, acquirer].include?(current_president)
              shortage = 2 - entitlements.fetch(current_president, 0)
              if current_president.corporation? && shortage.positive? && entitlements.fetch(acquirer, 0) >= shortage
                entitlements[acquirer] -= shortage
                entitlements[current_president] += shortage
              end
              return current_president if entitlements.fetch(current_president, 0) >= 2
            end

            holder, count = entitlements
              .reject { |candidate, _count| [@game.share_pool, @game.bank, acquirer].include?(candidate) }
              .max_by { |candidate, count| [count, candidate&.corporation? ? 0 : 1, candidate&.name.to_s] }
            raise GameError, 'No holder has enough shares to become president after the merger' if count.to_i < 2

            holder
          end

          def reset_surviving_shares(acquirer)
            @game.shares_for_corporation(acquirer).each do |share|
              transfer_share(share, acquirer) unless share.owner == acquirer
            end
          end

          def transfer_share(share, new_owner)
            old_owner = share.owner
            return if old_owner == new_owner

            corporation = share.corporation
            corporation.share_holders[old_owner] -= share.percent
            corporation.share_holders[new_owner] += share.percent
            old_owner.shares_by_corporation[corporation].delete(share)
            new_owner.shares_by_corporation[corporation] << share
            share.owner = new_owner
          end

          def transfer_acquisition_assets(acquirer, target)
            target.spend(target.cash, acquirer) if target.cash.positive?

            @game.transfer(:trains, target, acquirer)

            target.companies.dup.each do |company|
              target.companies.delete(company)
              acquirer.companies << company
              company.owner = acquirer
            end

            target.corporate_shares.dup.each do |share|
              next if [acquirer, target].include?(share.corporation)

              transfer_share(share, acquirer)
            end
          end

          def move_acquisition_share_price(acquirer, new_price)
            old_price = acquirer.share_price
            old_price.corporations.delete(acquirer)
            new_price.corporations << acquirer
            acquirer.share_price = new_price
            @log << "#{acquirer.name}'s new share price is #{@game.format_currency(new_price.price)}"
          end
        end
      end
    end
  end
end
