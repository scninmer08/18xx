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

            %w[acquire_company pass]
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
            raise GameError, "Cannot acquire #{company.name}" unless available_companies.include?(company)

            from_development_pool = company.owner.nil?

            unless from_development_pool
              president = corp.owner
              president.companies.delete(company) if president.is_a?(Engine::Player)
            end

            company.owner = corp
            @game.update_private_name!(company)
            corp.companies << company
            @log << if from_development_pool
                      "#{corp.name} acquires #{company.name} (Class #{private_class}) from the development pool"
                    else
                      "#{corp.name} receives #{company.name} (Class #{private_class}) from its president"
                    end
            @chosen_for << corp
          end

          def process_pass(action)
            @log << "#{action.entity.name} declines to assign a private company"
            @chosen_for << @round.converted
          end

          def companies_to_display
            available_companies
          end

          def log_skip(_entity); end

          private

          # Medium (5-share) corporations receive class B privates; large (10-share) receive class A.
          def private_class
            medium_share_count = @game.class::CORPORATION_SIZES.key(:medium)
            @round.converted&.total_shares == medium_share_count ? :B : :A
          end

          def available_companies
            return [] unless @round.converted

            corp = @round.converted
            president = corp.owner
            @game.eligible_private_acquisitions(corp, president)
              .select { |company| company.meta[:class] == private_class }
          end
        end
      end
    end
  end
end
