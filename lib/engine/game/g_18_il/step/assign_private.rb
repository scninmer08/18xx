# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        # Two-phase bid step: phase 1 selects a private (shows private cards),
        # phase 2 selects a corporation lot (shows concession cards).
        # Players assign their drafted privates to their lot corporations in turn order.
        class AssignPrivate < Engine::Step::Base
          ACTIONS = %w[bid].freeze

          attr_reader :selected_private

          def setup
            @selected_private = nil
          end

          def available
            if @selected_private
              cls = @selected_private.meta[:class]
              concessions = current_entity.companies
                .select { |c| c.meta[:type] == :concession }
                .reject { |c| corp_has_class?(corp_for(c), cls) }
              [@selected_private] + concessions
            else
              current_entity.companies.select { |c| c.meta[:type] == :private }
            end
          end

          def tiered_auction_companies
            unless @selected_private
              privates = current_entity.companies.select { |c| c.meta[:type] == :private }
              concessions = current_entity.companies.select { |c| c.meta[:type] == :concession }
              tiers = [privates.select { |c| c.meta[:class] == :A },
                       privates.select { |c| c.meta[:class] == :B }].reject(&:empty?)
              tiers << concessions unless concessions.empty?
              return tiers
            end

            cls = @selected_private.meta[:class]
            concessions = current_entity.companies
              .select { |c| c.meta[:type] == :concession }
              .reject { |c| corp_has_class?(corp_for(c), cls) }
            [[@selected_private], concessions]
          end

          def auctioning
            nil
          end

          def bids
            {}
          end

          def visible?
            true
          end

          def players_visible?
            true
          end

          def may_purchase?(_company)
            false
          end

          def may_choose?(company)
            return false if company == @selected_private
            return false if @selected_private.nil? && company.meta[:type] == :concession

            true
          end

          def committed_cash(_player, _show_hidden = false)
            0
          end

          def min_bid(_company)
            0
          end

          def description
            if @selected_private
              "Assign #{@selected_private.name} (Class #{@selected_private.meta[:class]}) to a Corporation"
            else
              'Assign Privates to Corporations'
            end
          end

          def help
            player = current_entity
            return [] unless player

            if @selected_private
              cls = @selected_private.meta[:class]
              ["Assign #{@selected_private.name} (Class #{cls}) to a concession:"]
            else
              remaining = player.companies.count { |c| c.meta[:type] == :private }
              ["#{player.name} has #{remaining} #{remaining == 1 ? 'private' : 'privates'} to assign. " \
               'Select a private and assign it to a concession.']
            end
          end

          def actions(entity)
            return [] unless entity == current_entity
            return [] if current_entity.companies.none? { |c| c.meta[:type] == :private }

            ACTIONS
          end

          def process_bid(action)
            company = action.company
            player = action.entity

            if @selected_private
              # Phase 2: company is a concession → find the corporation and assign
              corp = corp_for(company)
              raise GameError, "Invalid corporation lot: #{company.sym}" unless corp

              cls = @selected_private.meta[:class]
              raise GameError, "#{corp.full_name} already has a Class #{cls} private" if corp_has_class?(corp, cls)

              do_assignment(@selected_private, corp, player)
              @log << "#{player.name} assigns #{@selected_private.name} to #{corp.full_name} (#{corp.name})"
              @selected_private = nil

              if player.companies.none? { |c| c.meta[:type] == :private }
                if @game.players.all? { |p| p.companies.none? { |c| c.meta[:type] == :private } }
                  pass!
                else
                  @round.next_entity_index!
                end
              end
            else
              # Phase 1: company is a private → store it as the selection
              raise GameError, "#{company.name} is not your private" unless player.companies.include?(company)

              @selected_private = company
            end
          end

          private

          def corp_for(concession)
            @game.corporations.find { |corp| corp.name == concession.sym }
          end

          def corp_has_class?(corp, cls)
            corp&.companies&.any? { |c| c.meta[:type] == :private && c.meta[:class] == cls }
          end

          def do_assignment(company, corp, player)
            player.companies.delete(company)
            company.owner = corp
            company.instance_variable_set(:@color, corp.color)
            company.instance_variable_set(:@text_color, corp.text_color)
            corp.companies << company
          end
        end
      end
    end
  end
end
