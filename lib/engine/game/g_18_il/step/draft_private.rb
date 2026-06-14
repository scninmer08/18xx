# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class DraftPrivate < Engine::Step::Base
          ACTIONS = %w[bid].freeze

          def setup
            @available = @game.companies.select { |c| c.meta[:type] == :private }
                                        .sort_by { |c| [c.meta[:class].to_s, c.name] }
          end

          def actions(entity)
            return [] unless entity == current_entity
            return [] if available_for(entity).empty?

            ACTIONS
          end

          def description
            'Draft Private Company'
          end

          def help
            player = current_entity
            return [] unless player

            a_count = player.companies.count { |c| c.meta[:type] == :private && c.meta[:class] == :A }
            b_count = player.companies.count { |c| c.meta[:type] == :private && c.meta[:class] == :B }
            remaining = @available.size
            a_str = "#{a_count} Class A #{a_count == 1 ? 'private' : 'privates'}"
            b_str = "#{b_count} Class B #{b_count == 1 ? 'private' : 'privates'}"
            r_str = "#{remaining} #{remaining == 1 ? 'private' : 'privates'}"
            ["#{player.name} has drafted #{a_str} and #{b_str}. " \
             "#{r_str} remaining in the pool. " \
             "Each player may draft no more than #{draft_cap} of each class."]
          end

          def draft_cap
            4
          end

          def process_bid(action)
            company = action.company
            player = action.entity

            raise GameError, "#{company.name} is not available to draft" unless @available.include?(company)

            cls = company.meta[:class]
            already = player.companies.count { |c| c.meta[:type] == :private && c.meta[:class] == cls }
            raise GameError, "#{player.name} already has #{draft_cap} Class #{cls} privates" if already >= draft_cap

            company.owner = player
            player.companies << company
            @available.delete(company)

            @log << "#{player.name} drafts #{company.name} (Class #{company.meta[:class]})"
            @game.update_private_name!(company)

            if draft_complete?
              pass!
            else
              next_drafter!
            end
          end

          def available
            available_for(current_entity)
          end

          def available_for(player)
            return [] unless player

            @available.reject do |company|
              player.companies.count { |c| c.meta[:type] == :private && c.meta[:class] == company.meta[:class] } >= draft_cap
            end
          end

          def tiered_auction_companies
            avail = available
            [avail.select { |c| c.meta[:class] == :A },
             avail.select { |c| c.meta[:class] == :B }].reject(&:empty?)
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

          def may_choose?(_company)
            true
          end

          def committed_cash(_player, _show_hidden = false)
            0
          end

          def min_bid(_company)
            0
          end

          private

          def draft_complete?
            @game.players.all? do |player|
              %i[A B].all? do |cls|
                player.companies.count { |c| c.meta[:type] == :private && c.meta[:class] == cls } >= draft_cap
              end
            end
          end

          def next_drafter!
            loop do
              @round.next_entity_index!
              break unless available_for(current_entity).empty?
            end
          end
        end
      end
    end
  end
end
