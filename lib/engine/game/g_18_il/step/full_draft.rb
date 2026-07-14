# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class FullDraft < Engine::Step::Base
          ACTIONS = %w[bid].freeze
          CATEGORY_CAPS = {
            2 => 4,
            3 => 2,
            4 => 2,
            5 => 1,
            6 => 1,
          }.freeze

          def setup
            @available = @game.companies
              .select { |c| %i[concession private].include?(c.meta[:type]) }
              .sort_by { |c| [category_sort(c), c.name] }
            @available.select { |c| c.meta[:type] == :concession }.each { |c| change_concession_description(c) }
          end

          def actions(entity)
            return [] unless entity == current_entity
            return [] if available_for(entity).empty?

            ACTIONS
          end

          def description
            'Draft Concession or Private Company'
          end

          def help
            player = current_entity
            return [] unless player

            counts = draft_counts(player)
            remaining = @available.size
            ["#{player.name} has drafted #{category_phrase(:concession, counts[:concession])}, " \
             "#{category_phrase(:A, counts[:A])}, and #{category_phrase(:B, counts[:B])}. " \
             "#{remaining} #{remaining == 1 ? 'item' : 'items'} remaining. " \
             "Each player drafts #{category_phrase(:concession, category_cap)}, " \
             "#{category_phrase(:A, category_cap)}, and #{category_phrase(:B, category_cap)}."]
          end

          def process_bid(action)
            company = action.company
            player = action.entity

            raise GameError, "#{company.name} is not available to draft" unless @available.include?(company)

            category = draft_category(company)
            already = draft_counts(player)[category]
            raise GameError, "#{player.name} already has #{category_phrase(category, category_cap)}" if already >= category_cap

            company.owner = player
            player.companies << company
            @available.delete(company)

            @log << "#{player.name} drafts #{company.name} (#{category_name(category, 1)})"

            if draft_complete?
              log_undrafted_items!
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

            counts = draft_counts(player)
            @available.reject { |company| counts[draft_category(company)] >= category_cap }
          end

          def tiered_auction_companies
            avail = available
            [
              avail.select { |c| draft_category(c) == :concession },
              avail.select { |c| draft_category(c) == :A },
              avail.select { |c| draft_category(c) == :B },
            ].reject(&:empty?)
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

          def category_cap
            CATEGORY_CAPS.fetch(@game.players.size)
          end

          def draft_complete?
            @game.players.all? do |player|
              draft_counts(player).values.all? { |count| count >= category_cap }
            end
          end

          def next_drafter!
            loop do
              @round.next_entity_index!
              break unless available_for(current_entity).empty?
            end
          end

          def log_undrafted_items!
            return if @available.empty?

            concessions = @available.select { |company| company.meta[:type] == :concession }
            privates = @available.select { |company| company.meta[:type] == :private }
            unless concessions.empty?
              @log << "Undrafted concessions added to Auction Pool: #{@game.list_with_and(concessions.map(&:name))}"
            end
            return if privates.empty?

            @log << "Undrafted privates placed in Development Pool: #{@game.list_with_and(privates.map(&:name))}"
          end

          def draft_counts(player)
            {
              concession: player.companies.count { |c| draft_category(c) == :concession },
              A: player.companies.count { |c| draft_category(c) == :A },
              B: player.companies.count { |c| draft_category(c) == :B },
            }
          end

          def draft_category(company)
            company.meta[:type] == :concession ? :concession : company.meta[:class]
          end

          def category_sort(company)
            { concession: 0, A: 1, B: 2 }[draft_category(company)]
          end

          def category_phrase(category, count)
            "#{count} #{category_name(category, count)}"
          end

          def category_name(category, count)
            case category
            when :concession then count == 1 ? 'concession' : 'concessions'
            when :A then count == 1 ? 'Class A private' : 'Class A privates'
            when :B then count == 1 ? 'Class B private' : 'Class B privates'
            end
          end

          def change_concession_description(company)
            corp = @game.corporations.find { |c| c.name == company.sym }
            share_count = company&.meta&.[](:share_count)

            desc = "Can start #{company.sym}"
            desc += " (#{corp.coordinates})" if corp&.coordinates
            desc += " as a #{share_count}-share corporation."

            if corp && (corp.cash.positive? || corp.trains.any?)
              cash_part = corp.cash.positive? ? @game.format_currency(corp.cash) : nil
              trains_part = train_description(corp.trains) if corp.trains.any?
              parts = [cash_part, trains_part].compact
              desc += "\n\nCorporation holdings: #{parts.join(' and ')}" unless parts.empty?
            end

            company.desc = desc
          end

          def train_description(trains)
            items = trains.map { |train| train.name.match?(/^\d$/) ? "#{train.name}-" : train.name }
            if items.size == 1
              name = items.first
              name.end_with?('-') ? "#{name}train" : "#{name} train"
            else
              "#{@game.list_with_and(items)} trains"
            end
          end
        end
      end
    end
  end
end
