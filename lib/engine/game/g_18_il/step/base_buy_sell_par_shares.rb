# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'
require_relative '../../../step/share_buying'
require_relative '../../../action/buy_shares'
require_relative '../../../action/par'

module Engine
  module Game
    module G18IL
      module Step
        class BaseBuySellParShares < Engine::Step::BuySellParShares
          def actions(entity)
            return corporate_actions(entity) if !entity.player? && entity.owned_by?(current_entity)
            return [] unless entity.player?

            if @corporate_action
              return [] unless entity.owner == current_entity
              return ['pass'] if any_corporate_actions?(entity)

              return []
            end

            return [] unless entity == current_entity

            actions = super

            if (actions.any? || any_corporate_actions?(entity)) && !actions.include?('pass') && !must_sell?(entity)
              actions << 'pass'
            end

            actions
          end

          def process_sell_shares(action)
            super
            action.bundle.shares.each { |s| s.buyable = true }
          end

          def corporate_actions(entity)
            return [] if @corporate_action && @corporate_action.entity != entity
            #  return [] if entity == @game.ic
            return [] if must_sell?(entity.owner)

            actions = []
            actions << 'buy_shares' if @round.current_actions.none? && !@game.redeemable_shares(entity).empty?
            actions
          end

          def log_pass(entity)
            if @corporate_action
              @log << "#{entity.name} finishes acting for #{@corporate_action.entity.name}"
            elsif @round.current_actions.empty?
              @log << "#{entity.name} passes"
            end
          end

          def can_sell_order?
            !bought?
          end

          def any_corporate_actions?(entity)
            @game.corporations.any? { |corp| corp.owner == entity && !corporate_actions(corp).empty? }
          end

          def description
            'Sell then Buy Shares'
          end

          def round_state
            super.merge(
              { corp_started: nil },
              { reserve_bought: Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } } },
            )
          end

          def setup
            super
            @round.corp_started = nil
            @corporate_action = nil
          end

          def visible_corporations
            started_corps = @game.sorted_corporations.select(&:ipoed)
            potential_corps = @game.sorted_corporations.select do |corp|
              @game.players.find do |player|
                @game.can_par?(corp, player)
              end
            end
            (started_corps + potential_corps)
          end

          def can_buy_any_from_player?(_entity)
            false
          end

          def can_buy_any?(entity)
            (can_buy_any_from_market?(entity) ||
            can_buy_any_from_ipo?(entity) ||
            can_buy_any_from_player?(entity) ||
            can_buy_any_from_reserve?(entity))
          end

          def can_buy_any_from_reserve?(entity)
            @game.corporations.each do |corporation|
              next unless corporation.owner == entity

              reserve_shares = corporation.shares - corporation.ipo_shares
              return true if can_buy_shares?(entity, reserve_shares)
            end

            false
          end

          def can_buy_any_from_ipo?(entity)
            @game.corporations.each do |corporation|
              next unless corporation.ipoed
              return true if can_buy_shares?(entity, corporation.ipo_shares)
            end

            false
          end

          def can_buy?(entity, bundle)
            can_gain?(entity, bundle)
          end

          def pass!
            @round.current_actions << @corporate_action
            super
            post_share_pass_step! if @round.corp_started
          end

          def can_sell_any_of_corporation?(entity, corporation)
            bundles = @game.bundles_for_corporation(entity, corporation).reject { |b| b.corporation == entity }
            bundles.any? { |bundle| can_sell?(entity, bundle) }
          end

          def can_sell?(entity, bundle)
            return false if bundle.corporation == @game.ic && @game.ic_in_receivership?
            return false if @game.insolvent_corporations.include?(bundle.corporation)

            super && !@corporate_action
          end

          def can_dump?(entity, bundle)
            return true unless bundle.presidents_share

            sh = bundle.corporation.player_share_holders(corporate: false)
            (sh.reject { |k, _| k == entity }.values.max || 0) >= bundle.presidents_share.percent
          end

          def check_legal_buy(entity, shares, exchange: nil, swap: nil, allow_president_change: true); end

          def can_gain?(entity, bundle, exchange: false)
            return false if !entity || !bundle
            return false unless bundle.buyable

            corporation = bundle.corporation

            # disallow buying from a player; allow from market/IPO/treasury/etc.
            return false if bundle.owner.player?

            # reservation rule: only the reserver’s corp may gain the reserved bundle
            return false if reserve_bundle?(corporation, bundle.owner) && bundle.owner.owner != entity

            # insolvent corps cannot have their stock purchased
            return false if @game.insolvent_corporations.include?(corporation)

            return entity.cash >= bundle.price && redeemable_shares(entity).include?(bundle) if entity.corporation?

            has_cash = available_cash(entity) >= modify_purchase_price(bundle)
            not_sold = !(@round.players_sold[entity] && @round.players_sold[entity][corporation])
            return false if !has_cash || !not_sold || bought?

            can_hold = corporation.holding_ok?(entity, bundle.common_percent)
            at_limit = @game.num_certs(entity) >= @game.cert_limit(entity)

            return true if reserve_bundle?(corporation, bundle.owner) && bundle.corporation == @game.ic && !at_limit

            !at_limit && can_hold
          end

          def must_sell?(entity)
            return true if @game.num_certs(entity) > @game.cert_limit(entity)

            false
          end

          def reserve_bundle?(bundle_corporation, bundle_owner)
            bundle_owner != bundle_corporation && bundle_owner.is_a?(Corporation)
          end

          def process_buy_shares(action)
            entity = action.entity
            bundle = action.bundle
            corporation = bundle.corporation
            ic = @game.ic

            if entity.player?
              @round.players_bought[entity][corporation] += bundle.percent
              @round.bought_from_ipo = true if bundle.owner.corporation? && bundle.owner == corporation
              track_action(action, corporation)
              @round.reserve_bought[entity][corporation].concat(bundle.shares) if reserve_bundle?(corporation, bundle.owner)
              buy_shares(action.purchase_for || entity, bundle,
                         swap: action.swap, borrow_from: action.borrow_from,
                         allow_president_change: allow_president_change?(corporation),
                         discounter: action.discounter)

              if entity.player? && entity == ic.owner && @game.ic_in_receivership?
                ic_shares = entity.shares_of(ic)[0, 2]
                ic_shares.each { |share| share.buyable = false }

                bundle = ShareBundle.new(ic_shares)
                @game.share_pool.transfer_shares(bundle, ic)
                ic.presidents_share.buyable = true
                bundle = ShareBundle.new(ic.presidents_share)
                @game.share_pool.transfer_shares(bundle, entity)
              end
              @game.add_ic_operating_ability if corporation == ic && !@game.ic_in_receivership?

            else
              buy_shares(entity, bundle)
              track_action(action, corporation, false)
              @corporate_action = action
            end
          end

          def redeemable_shares(entity)
            return [] if @corporate_action && entity != @corporate_action.entity

            @game.redeemable_shares(entity)
          end

          def process_par(action)
            @round.corp_started = action.corporation
            super
            company = @game.company_by_id(action.corporation.name)
            if !@game.intro_game? && @game.extra_station&.owner == action.corporation
              @log << "#{action.corporation.name} gains an extra station"
              @log << "#{@game.extra_station.name} (#{action.corporation.name}) closes"
              @game.extra_station.close!

              action.corporation.tokens << Engine::Token.new(action.corporation, price: 0)
            end
            @game.companies.delete(company)
            company.close!
          end

          def post_share_pass_step!
            corp = @round.corp_started

            return if @game.closed_corporations.delete(corp)

            case corp.total_shares
            when 10
              min = 2
              max = 4
              @log << "#{corp.name} must buy between #{min} and #{max} tokens"
            when 5
              min = 1
              max = 1
              @log << "#{corp.name} must buy #{min} token"
            when 2
              @log << "#{corp.name} does not buy tokens"
              return
            end

            price = @game.class::TOKEN_COST

            @round.buy_tokens << {
              entity: corp,
              type: :start,
              first_price: price,
              price: price,
              min: min,
              max: max,
            }
          end
        end
      end
    end
  end
end
