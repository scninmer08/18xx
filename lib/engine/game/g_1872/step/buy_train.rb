# frozen_string_literal: true

require_relative '../../../step/buy_train'

module Engine
  module Game
    module G1872
      module Step
        class BuyTrain < Engine::Step::BuyTrain
          def actions(entity)
            return [] if isolated_shell?(entity)

            if entity == @game.acting_for_entity(current_entity) && president_may_contribute?(current_entity) &&
               president_needs_to_sell_shares?(current_entity, entity) && sellable_bundles(entity, nil).any?
              return ['sell_shares']
            end

            return [] unless can_entity_buy_train?(entity)
            return [] unless entity == current_entity
            return %w[buy_train sell_shares] unless issuable_shares(entity).empty?
            return ['buy_train'] if must_buy_train?(entity)

            super
          end

          def setup
            super
            @emr_triggered = false
          end

          def corp_owner(corporation)
            @game.acting_for_entity(corporation)
          end

          alias real_owner corp_owner

          def can_entity_buy_train?(entity)
            !isolated_shell?(entity) && super
          end

          def president_may_contribute?(corporation, _shell = nil)
            return false unless must_buy_train?(corporation)
            return false unless @game.emergency_issuable_bundles(corporation).empty?

            @game.chain_of_corps(corporation).sum(&:cash) < @game.depot.min_depot_price
          end

          alias ebuy_president_can_contribute? president_may_contribute?

          def can_ebuy_sell_shares?(corporation)
            president = @game.acting_for_entity(corporation)
            president_may_contribute?(corporation) &&
              president_needs_to_sell_shares?(corporation, president)
          end

          def buyable_trains(entity)
            trains = super
            return trains unless @emr_triggered

            trains.select(&:from_depot?)
          end

          def other_trains(entity)
            super.select { |train| connected_train_owner?(entity, train.owner) }
          end

          def train_variant_helper(train, entity)
            return train.variants.values if train.from_depot?

            super
          end

          def issuable_shares(entity)
            return [] unless must_buy_train?(entity)

            @game.emergency_issuable_bundles(entity)
          end

          def available_cash(corporation)
            corporation.cash
          end

          def available_cash_str(corporation)
            available = emr_chain_cash(corporation)
            return @game.format_currency(corporation.cash) if available == corporation.cash

            "#{@game.format_currency(corporation.cash)} (#{@game.format_currency(available)} EMR cash is available)"
          end

          def cheapest_train_price(corporation)
            @depot.min_depot_price - [emr_chain_cash(corporation) - corporation.cash, 0].max
          end

          def issuing_corporation(corporation)
            issuable_shares(corporation).first&.owner || corporation
          end

          def issue_text(entity)
            owner = issuable_shares(entity).first&.owner
            return 'EMR Sell/Issue Shares' unless owner

            verb = issuable_shares(entity).first.corporation == owner ? 'Issue' : 'Sell'
            "#{owner.name} EMR #{verb} Shares#{owner == entity ? '' : " (for #{entity.name})"}"
          end

          def issue_verb(_entity)
            'sell/issue'
          end

          def issue_corp_name(bundle)
            bundle.corporation.name
          end

          def can_sell?(_entity, bundle)
            corporate_bundles = issuable_shares(current_entity)
            return corporate_bundles.any? { |candidate| candidate == bundle } if bundle.owner&.corporation?

            sellable_bundles(bundle.owner, bundle.corporation).any? { |candidate| candidate == bundle }
          end

          def sellable_bundles(entity, corporation)
            return [] unless entity&.player?
            return [] unless entity == @game.acting_for_entity(current_entity)
            return [] unless president_may_contribute?(current_entity)
            return [] unless president_needs_to_sell_shares?(current_entity, entity)

            @game.emergency_player_sellable_bundles(entity, current_entity, corporation, allow_unoperated: true)
          end

          def process_sell_shares(action)
            bundle = action.bundle
            raise GameError, 'That share bundle cannot be used for emergency money raising' unless
              can_sell?(action.entity, bundle)

            seller = bundle.owner
            @game.sell_shares_and_change_price(
              bundle,
              allow_president_change: !@game.sponsored_corporation?(bundle.corporation),
            )
            @emr_triggered = true
            @round.recalculate_order if @round.respond_to?(:recalculate_order)
          end

          def process_buy_train(action)
            entity = action.entity
            if @emr_triggered && !action.train.from_depot?
              raise GameError, 'After beginning emergency money raising, the train must be bought from the depot'
            end
            unless action.train.from_depot? || connected_train_owner?(entity, action.train.owner)
              raise GameError, "#{entity.name} is not connected to #{action.train.owner.name}"
            end

            if entity.cash < action.price && !must_buy_train?(entity)
              raise GameError, "#{entity.name} does not have #{@game.format_currency(action.price)}"
            end

            if entity.cash < action.price && !issuable_shares(entity).empty?
              raise GameError, "#{issuing_corporation(entity).name} must sell or issue shares before buying the train"
            end

            sweep_cash(entity, @game.acting_for_entity(entity), action.price) if entity.cash < action.price
            super
            @emr_triggered = false
          end

          private

          def isolated_shell?(entity)
            entity&.corporation? && @game.isolated_shell?(entity)
          end

          def emr_chain_cash(corporation)
            @game.emergency_cash_before_issuing(corporation)
          end

          def president_needs_to_sell_shares?(corporation, president)
            president.cash < [@depot.min_depot_price - emr_chain_cash(corporation), 0].max
          end

          def connected_train_owner?(buyer, seller)
            return true unless seller&.corporation?

            buyer_token_corporation = @game.token_corporation(buyer)
            seller_token_corporation = @game.token_corporation(seller)
            return true if buyer_token_corporation == seller_token_corporation

            connected_nodes = @game
              .token_graph_for_entity(buyer_token_corporation)
              .connected_nodes(buyer_token_corporation)
              .keys

            seller_token_corporation.tokens.any? do |token|
              token.used && token.city && connected_nodes.include?(token.city)
            end
          end

          def sweep_cash(entity, stop_at, cost)
            return if entity == stop_at

            @game.chain_of_control(entity).each do |controller|
              break unless controller

              amount = [[cost - entity.cash, 0].max, controller.cash].min
              if amount.positive?
                controller.spend(amount, entity)
                @log << "#{controller.name} contributes #{@game.format_currency(amount)} to #{entity.name}"
              end
              break if controller == stop_at || entity.cash >= cost
            end
          end
        end
      end
    end
  end
end
