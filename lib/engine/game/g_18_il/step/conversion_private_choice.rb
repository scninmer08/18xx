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
            return [] unless entity == corporation
            return [] if eligible_private_companies.empty?

            %w[acquire_company pass]
          end

          def choices
            {}
          end

          def choice_name
            "Choose a private company to acquire for #{corporation&.name}"
          end

          def choice_available?(_entity)
            false
          end

          def active?
            corporation &&
              !@chosen_for.include?(corporation)
          end

          def active_entities
            return [] unless active?

            [corporation]
          end

          def description
            "Choose Private Company for #{corporation&.name}"
          end

          def pass_description
            'Pass (Acquire)'
          end

          def process_acquire_company(action)
            corp = corporation
            company = action.company
            raise GameError, "Cannot acquire #{company.name}" unless eligible_private_companies.include?(company)

            from_development_pool = company.owner.nil?

            unless from_development_pool
              president = corp.owner
              president.companies.delete(company) if president.is_a?(Engine::Player)
            end

            company.owner = corp
            corp.companies << company
            @log << if from_development_pool
                      "#{corp.name} acquires #{company.name} from the Development Pool"
                    else
                      "#{corp.name} receives #{company.name} from its president"
                    end
            finish_private_choice!(corp) if eligible_private_companies.empty?
          end

          def process_pass(action)
            @log << "#{action.entity.name} passes private acquisition"
            finish_private_choice!(corporation)
          end

          def eligible_private_companies
            corp = corporation
            return [] unless corp

            president = corp.owner
            @game.eligible_private_acquisitions(corp, president)
          end

          def skip!
            corp = corporation
            @log << "#{corp.name} skips private acquisition" if corp
            finish_private_choice!(corp)
          end

          private

          def corporation
            @round.private_choice_corporation
          end

          def finish_private_choice!(corp)
            return unless corp

            @chosen_for << corp
            @round.private_choice_corporation = nil if @round.private_choice_corporation == corp
            @round.clear_cache!
          end
        end
      end
    end
  end
end
