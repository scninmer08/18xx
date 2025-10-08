# frozen_string_literal: true

module Engine
  module Game
    module G18FLOOD
      class SharePool < Engine::SharePool
        private

        # Use the game's label hook if present (defaults to 'president')
        def label_for(corporation)
          @game.respond_to?(:president_label_for) ? @game.president_label_for(corporation) : 'president'
        end

        # Copied from Engine::SharePool#transfer_shares with only the presidency log lines changed
        def transfer_shares(bundle, to_entity,
                            spender: nil,
                            receiver: nil,
                            price: nil,
                            allow_president_change: true,
                            swap: nil,
                            borrow_from: nil,
                            swap_to_entity: nil,
                            corporate_transfer: nil)
          corporation = bundle.corporation
          owner = bundle.owner
          previous_president = bundle.president
          price ||= bundle.price

          corporation.share_holders[owner] -= bundle.percent
          corporation.share_holders[to_entity] += bundle.percent

          if swap
            corporation.share_holders[swap.owner] -= swap.percent
            corporation.share_holders[swap_to_entity] += swap.percent
            move_share(swap, swap_to_entity)
          end

          if corporation.capitalization == :escrow && receiver == corporation
            if corporation.percent_of(corporation) > 50 && spender && price.positive?
              spender.spend(price, receiver) if spender && receiver
            else
              spender.spend(price, @bank)
              corporation.escrow += price
            end
          elsif spender && receiver && price.positive?
            spender.spend(price, receiver, borrow_from: borrow_from)
          end

          bundle.shares.each { |s| move_share(s, to_entity) }

          return unless allow_president_change

          max_shares = presidency_check_shares(corporation).values.max || 0

          # President's share sold to the market (receivership); change log text
          if @allow_president_sale && max_shares < corporation.presidents_percent && bundle.presidents_share &&
              to_entity == self
            corporation.owner = self
            @log << "#{label_for(corporation).capitalize}'s share sold to market. " \
                    "#{corporation.name} enters receivership"
            return unless bundle.partial?

            handle_partial(bundle, self, owner)
            return
          end

          # Buying president's share back from market; change log text
          if @allow_president_sale && owner == self && bundle.presidents_share
            corporation.owner = to_entity
            @log << "#{to_entity.name} becomes the #{label_for(corporation)} of #{corporation.name}"
            @log << "#{corporation.name} exits receivership"
            handle_partial(bundle, to_entity, self)
            return
          end

          # Skip if no player can be president yet
          return if @allow_president_sale && max_shares < corporation.presidents_percent

          majority_share_holders = presidency_check_shares(corporation).select { |_, p| p == max_shares }.keys

          return if majority_share_holders.any? { |player| player == previous_president }

          unless previous_president
            president = majority_share_holders.find do |player|
              player == corporation.presidents_share.owner
            end
          end
          president ||= majority_share_holders
            .select { |p| p.percent_of(corporation) >= corporation.presidents_percent }
            .min_by do |p|
              if previous_president == self
                0
              else
                (if @game.respond_to?(:player_distance_for_president)
                   @game.player_distance_for_president(previous_president, p)
                 else
                   distance(previous_president, p)
                 end)
              end
            end
          return unless president

          corporation.owner = president
          @log << "#{president.name} becomes the #{label_for(corporation)} of #{corporation.name}"

          return if to_entity == president && previous_president == owner && bundle.presidents_share && !bundle.partial?

          if owner == corporation &&
              !bundle.presidents_share &&
              @game.can_swap_for_presidents_share_directly_from_corporation?
            previous_president ||= corporation
          end
          return if owner == president || !previous_president

          presidents_share = bundle.presidents_share || previous_president.shares_of(corporation).find(&:president)
          return unless presidents_share

          if ((owner.player? && to_entity.player?) || corporate_transfer) && bundle.presidents_share
            transfer_to = to_entity
            swap_to = to_entity
          else
            transfer_to = @game.sold_shares_destination(corporation) == :corporation ? corporation : self
            swap_to = previous_president.percent_of(corporation) >= presidents_share.percent ? previous_president : transfer_to
          end

          change_president(presidents_share, swap_to, president, previous_president)

          return unless bundle.partial?

          handle_partial(bundle, transfer_to, owner)
        end
      end
    end
  end
end
