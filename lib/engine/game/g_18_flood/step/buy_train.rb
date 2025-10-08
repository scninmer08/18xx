# frozen_string_literal: true

require_relative '../../../step/buy_train'

module Engine
  module Game
    module G18FLOOD
      module Step
        class BuyTrain < Engine::Step::BuyTrain
          def actions(entity)
            return [] if @game.national_corporation?(entity)
            return [] if entity != current_entity

            %w[buy_train pass]
          end

          def process_pass(action)
            entity = action.entity

            if entity.trains.empty?
              @log << "#{entity.name} did not buy a train and closes"
              @game.close_corporation(entity, quiet: true)
            else
              pass!
            end
          end

          def must_buy_train?(_entity)
            false
          end

          def log_skip(entity)
            return if @game.national_corporation?(entity)

            super
          end

          def buyable_trains(entity)
            trains = super
            return trains unless @game.shell_corporation?(entity)

            buyer_parent = @game.shell_parent[entity]

            trains.select do |t|
              seller = t.owner

              # Allow depot (or anything non-corp), engine will handle reservations
              next true if !seller.respond_to?(:corporation?) || !seller.corporation?

              # If seller is a shell, only allow when both shells share the same parent
              if @game.shell_corporation?(seller)
                @game.shell_parent[seller] == buyer_parent
              else
                # Seller is a national/other corp: disallow for shells
                false
              end
            end
          end
        end
      end
    end
  end
end
