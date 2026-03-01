# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        class ConversionPrivateChoice < Engine::Step::Base
          def setup
            @chosen_for = []
          end

          def actions(entity)
            return [] unless active?
            return [] unless entity == current_entity

            %w[acquire_company choose]
          end

          def choices
            {}
          end

          def choice_name
            "Choose a Class #{private_class} private company to acquire"
          end

          def choice_available?(_entity)
            false
          end

          def active?
            @round.converted &&
              !@chosen_for.include?(@round.converted) &&
              available_companies.any?
          end

          def active_entities
            return [] unless active?

            [@round.converted]
          end

          def description
            "Choose Private Company for #{@round.converted&.name}"
          end

          def process_acquire_company(action)
            corp = @round.converted
            company = action.company
            company.owner = corp
            corp.companies << company
            @log << "#{corp.name} receives #{company.name} (Class #{private_class})"
            @chosen_for << corp
          end

          def companies_to_display
            available_companies
          end

          def log_skip(_entity); end

          private

          def private_class
            @round.converted&.total_shares == 5 ? :B : :A
          end

          def available_companies
            return [] unless @round.converted

            @game.companies.select { |c| c.meta[:class] == private_class && c.owner.nil? }
          end
        end
      end
    end
  end
end
