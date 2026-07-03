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
          def round_state
            super.merge(corp_started: nil)
          end

          def setup
            super
            @round.corp_started = nil
          end

          def actions(entity)
            return [] unless entity.player?
            return [] unless entity == current_entity

            actions = super
            actions << 'pass' if actions.any? && !actions.include?('pass') && !must_sell?(entity)

            actions
          end

          def description
            'Sell then Buy Shares'
          end

          def log_pass(entity)
            @log << "#{entity.name} passes" if @round.current_actions.empty?
          end

          def process_sell_shares(action)
            super
            action.bundle.shares.each { |s| s.buyable = true }
          end

          def process_buy_shares(action)
            entity      = action.entity
            bundle      = action.bundle
            corporation = bundle.corporation
            ic          = @game.ic

            @round.players_bought[entity][corporation] += bundle.percent
            @round.bought_from_ipo = true if bundle.owner == corporation

            buy_shares(action.purchase_for || entity, bundle,
                       swap: action.swap, borrow_from: action.borrow_from,
                       allow_president_change: allow_president_change?(corporation),
                       discounter: action.discounter)
            track_action(action, corporation)

            if entity == ic.owner && @game.ic_in_receivership?
              ic_shares = entity.shares_of(ic)[0, 2]
              ic_shares.each { |share| share.buyable = false }

              @game.share_pool.transfer_shares(ShareBundle.new(ic_shares), ic)
              ic.presidents_share.buyable = true
              @game.share_pool.transfer_shares(ShareBundle.new(ic.presidents_share), entity)

              @game.sync_ic_operating_state!
            end

            @game.sync_ic_operating_state! if corporation == ic
          end

          def process_par(action)
            @round.corp_started = action.corporation
            super
            company = @game.company_by_id(action.corporation.name)
            @game.companies.delete(company)
            company.close!
          end

          def pass!
            super
            post_share_pass_step! if @round.corp_started
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

          def can_sell_order?
            !bought?
          end

          def get_par_prices(entity, _corporation)
            @game.par_prices.select { |price| price.price * 2 <= available_cash(entity) }
          end

          def can_sell?(entity, bundle)
            return false if bundle.corporation == @game.ic && @game.ic_in_receivership?
            return false if @game.insolvent_corporations.include?(bundle.corporation)

            super
          end

          def can_dump?(entity, bundle)
            return true unless bundle.presidents_share

            sh = bundle.corporation.player_share_holders(corporate: false)
            (sh.reject { |k, _| k == entity }.values.max || 0) >= bundle.presidents_share.percent
          end

          def can_buy?(entity, bundle)
            can_gain?(entity, bundle)
          end

          def can_buy_any_from_ipo?(entity)
            @game.corporations.each do |corporation|
              next unless corporation.ipoed
              return true if can_buy_shares?(entity, corporation.ipo_shares)
            end

            false
          end

          def can_buy_any?(entity)
            can_buy_any_from_market?(entity) ||
              can_buy_any_from_ipo?(entity) ||
              can_buy_any_corporate_ic?(entity)
          end

          def can_buy_any_corporate_ic?(entity)
            return false if bought?

            @game.corporations.any? do |seller|
              seller.president?(entity) && seller.shares_of(@game.ic).any? do |share|
                can_buy?(entity, share.to_bundle)
              end
            end
          end

          def can_gain?(entity, bundle, exchange: false)
            return false if !entity || !bundle

            corporation = bundle.corporation
            corporate_ic_purchase = corporation == @game.ic &&
              bundle.owner.corporation? && bundle.owner.president?(entity)
            return false unless bundle.buyable || corporate_ic_purchase

            # Disallow buying from a player, but allow buying from the Market, IPO, or Treasury.
            return false if bundle.owner.player?

            # Shares of insolvent corporations cannot be purchased.
            return false if @game.insolvent_corporations.include?(corporation)

            has_cash = available_cash(entity) >= modify_purchase_price(bundle)
            not_sold = !(@round.players_sold[entity] && @round.players_sold[entity][corporation])
            return false if !has_cash || !not_sold || bought?

            can_hold = bundle.owner == @game.share_pool || corporation.holding_ok?(entity, bundle.common_percent)
            at_limit = @game.num_certs(entity) >= @game.cert_limit(entity)

            !at_limit && can_hold
          end

          def must_sell?(entity)
            return true if @game.num_certs(entity) > @game.cert_limit(entity)

            false
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
        end
      end
    end
  end
end
