# frozen_string_literal: true

require_relative '../../../step/bankrupt'

module Engine
  module Game
    module G1872
      module Step
        class Bankrupt < Engine::Step::Bankrupt
          def actions(entity)
            return [] if entity&.corporation? && @game.isolated_branch?(entity)

            super
          end

          def process_bankrupt(action)
            corporation = action.entity
            player = @game.acting_for_entity(corporation)

            raise GameError, "#{corporation.name} does not have a player president" unless player&.player?

            validate_bankruptcy!(player, corporation)

            @log << "-- #{player.name} goes bankrupt and sells remaining shares --"

            bankrupt_presidencies = player.presidencies.dup
            @bankruptcy_receiverships = bankrupt_presidencies.flat_map { |corp| closing_family(corp) }.uniq
            sell_normally_allowed_shares(player, corporation, bankrupt_presidencies)
            sell_remaining_player_assets(player)
            close_bankrupt_presidencies(player, bankrupt_presidencies)
            @bankruptcy_receiverships = nil
            transfer_remaining_cash(player, corporation)
            close_player_companies(player)

            @game.declare_bankrupt(player)
            @round.clear_cache!
          end

          private

          def validate_bankruptcy!(player, corporation)
            return if @game.can_go_bankrupt?(player, corporation)

            buying_power = @game.format_currency(@game.total_emr_buying_power(player, corporation))
            price = @game.format_currency(@game.depot.min_depot_price)

            raise GameError, "Cannot go bankrupt. #{corporation.name}'s cash plus #{player.name}'s cash and "\
                             "sellable shares total #{buying_power}, and the cheapest train in the Depot costs "\
                             "#{price}."
          end

          def sell_normally_allowed_shares(player, active_corporation, bankrupt_presidencies)
            loop do
              bundle = best_emr_bundle(player, active_corporation)
              break unless bundle

              receivership = bankruptcy_receivership?(bundle.corporation)
              @game.sell_shares_and_change_price(
                bundle,
                allow_president_change: !receivership && !@game.sponsored_corporation?(bundle.corporation),
              )
              bundle.corporation.owner = @game.share_pool if receivership && bundle.presidents_share
            end
          end

          def best_emr_bundle(player, active_corporation)
            player.shares_by_corporation(sorted: true)
              .keys
              .filter_map do |corporation|
                next unless corporation.share_price

                @game
                  .emergency_player_sellable_bundles(player, active_corporation, corporation, allow_unoperated: true)
                  .max_by(&:price)
              end
              .max_by(&:price)
          end

          def sell_remaining_player_assets(player)
            player.shares_by_corporation(sorted: true).keys.each do |corporation|
              next unless corporation.share_price
              shares = shares_owned_by(player, corporation)
              next if shares.empty?

              bundle = ShareBundle.new(shares)
              bundle.share_price = corporation.share_price.price / 2.0
              receivership = bankruptcy_receivership?(corporation)
              @game.share_pool.sell_shares(bundle, allow_president_change: !receivership && !bundle.presidents_share)
              corporation.owner = @game.share_pool if bundle.presidents_share
            end
          end

          def close_bankrupt_presidencies(player, presidencies)
            presidencies
              .select { |corporation| @game.corporations.include?(corporation) }
              .each { |corporation| liquidate_corporation_family(corporation, bankrupt_player: player) }
          end

          def liquidate_corporation_family(corporation, bankrupt_player:)
            @game.branch_children(corporation).dup.each do |child|
              liquidate_corporation_family(child, bankrupt_player: bankrupt_player)
            end

            return unless @game.corporations.include?(corporation)

            @log << "-- #{corporation.name} closes due to #{bankrupt_player.name}'s bankruptcy --"
            sell_owned_shares(corporation)
            sell_outstanding_shares(corporation)
            close_owned_companies(corporation)
            @game.close_corporation(corporation)
          end

          def sell_owned_shares(corporation)
            corporation.corporate_shares
              .group_by { |share| [share.corporation, share.owner] }
              .each_value do |shares|
                shares = shares.select { |share| share.owner == corporation }
                next if shares.empty?

                bundle = ShareBundle.new(shares)
                next unless bundle.corporation.share_price

                bundle.share_price = bundle.corporation.share_price.price
                receivership = bankruptcy_receivership?(bundle.corporation)
                @game.sell_shares_and_change_price(bundle, allow_president_change: !receivership)
                bundle.corporation.owner = @game.share_pool if receivership && bundle.presidents_share
              end
          end

          def sell_outstanding_shares(corporation)
            receivership = bankruptcy_receivership?(corporation)
            corporation.owner = @game.share_pool if receivership

            @game.shares_for_corporation(corporation)
              .reject { |share| [corporation, @game.share_pool].include?(share.owner) }
              .group_by(&:owner)
              .each do |owner, shares|
                shares = shares.select { |share| share.owner == owner }
                next if shares.empty?

                bundle = ShareBundle.new(shares)
                bundle.share_price = corporation.share_price.price
                @game.share_pool.sell_shares(bundle, allow_president_change: !receivership)
              end
          end

          def closing_family(corporation)
            return [] unless corporation && @game.corporations.include?(corporation)

            [corporation] + @game.branch_children(corporation).flat_map { |child| closing_family(child) }
          end

          def bankruptcy_receivership?(corporation)
            @bankruptcy_receiverships&.include?(corporation)
          end

          def close_owned_companies(corporation)
            companies = (corporation.companies + @game.companies.select { |company| company.owner == corporation }).uniq
            companies.reject!(&:closed?)
            return if companies.empty?

            @log << "#{corporation.name}'s companies close: #{companies.map(&:sym).join(', ')}"
            companies.each(&:close!)
          end

          def shares_owned_by(owner, corporation)
            owner.shares_of(corporation).select { |share| share.owner == owner }.dup
          end

          def transfer_remaining_cash(player, corporation)
            return unless player.cash.positive?

            unless @game.corporations.include?(corporation)
              player.set_cash(0, @game.bank)
              return
            end

            @log << "#{player.name} transfers #{@game.format_currency(player.cash)} to #{corporation.name}"
            player.spend(player.cash, corporation)
          end

          def close_player_companies(player)
            companies = (player.companies + @game.companies.select { |company| company.owner == player }).uniq
            companies.reject!(&:closed?)
            return if companies.empty?

            @log << "#{player.name}'s companies close: #{companies.map(&:sym).join(', ')}"
            companies.each(&:close!)
          end
        end
      end
    end
  end
end
