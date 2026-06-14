# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module G18IL
      module Step
        # After starting a corporation, it may acquire eligible privates from
        # the development pool or from its president.
        class AssignPrivateOnPar < Engine::Step::Base
          def round_state
            super.merge({ assign_privates_on_par: [] })
          end

          def active?
            @round.assign_privates_on_par.any?
          end

          def active_entities
            return [] unless active?

            [pending_player].compact
          end

          def pending_player
            @round.assign_privates_on_par.first&.dig(:player)
          end

          def pending_corp
            @round.assign_privates_on_par.first&.dig(:corp)
          end

          def actions(entity)
            return [] unless active?
            return [] unless entity == pending_player

            %w[choose]
          end

          def description
            "Acquire or Assign Privates to #{pending_corp&.name}"
          end

          def ipo_type(_entity)
            :par
          end

          def choice_available?(entity)
            entity == pending_player
          end

          def choice_name
            corp = pending_corp
            return '' unless corp

            "Acquire or assign a private to #{corp.name} (#{shares_desc(corp)})"
          end

          def choices
            corp = pending_corp
            player = pending_player
            return {} unless corp && player

            result = {}
            eligible_privates(player, corp).each do |c|
              result[c.sym] = "#{c.name} (Class #{c.meta[:class]})"
            end
            result['skip'] = 'Done assigning'
            result
          end

          def process_choose(action)
            corp = pending_corp
            player = pending_player

            if action.choice == 'skip'
              @round.assign_privates_on_par.shift
              @log << "#{player.name} finishes acquiring or assigning privates to #{corp.name}"
              return
            end

            company = @game.company_by_id(action.choice)
            raise GameError, "Invalid private: #{action.choice}" unless company

            eligible = eligible_privates(player, corp)
            raise GameError, "Cannot assign #{company.name} to #{corp.name}" unless eligible.include?(company)

            from_development_pool = company.owner.nil?
            player.companies.delete(company) if company.owner == player
            company.owner = corp
            @game.update_private_name!(company)
            company.instance_variable_set(:@color, corp.color)
            company.instance_variable_set(:@text_color, corp.text_color)
            corp.companies << company

            @log << if from_development_pool
                      "#{corp.name} acquires #{company.name} (Class #{company.meta[:class]}) from the development pool"
                    else
                      "#{player.name} assigns #{company.name} (Class #{company.meta[:class]}) to #{corp.name}"
                    end

            # Auto-finish if nothing more can be assigned
            @round.assign_privates_on_par.shift if eligible_privates(player, corp).empty?
          end

          def visible_corporations
            [pending_corp].compact
          end

          def log_skip(_entity); end

          def eligible_privates(player, corp)
            @game.eligible_private_acquisitions(corp, player)
          end

          def shares_desc(corp)
            case corp.total_shares
            when 5 then 'may receive 1 Class B private'
            when 10 then 'may receive 1 Class A and 1 Class B private'
            end
          end
        end
      end
    end
  end
end
