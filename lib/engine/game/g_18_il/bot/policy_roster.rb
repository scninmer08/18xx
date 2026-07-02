# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Bot
        class PolicyRoster
          attr_reader :profiles, :policies

          def initialize(profiles)
            @profiles = profiles
            @policies = profiles.each_with_index.to_h do |profile, index|
              ["Bot #{index + 1}", BaselinePolicy.new(profile: profile)]
            end
            @fallback = BaselinePolicy.new
          end

          def choose(game)
            player = controlling_player(game.round.current_entity)
            (policies[player&.id] || @fallback).choose(game)
          end

          private

          def controlling_player(entity)
            seen = {}
            until !entity || entity.player? || seen[entity]
              seen[entity] = true
              entity = entity.owner
            end
            entity if entity&.player?
          end
        end
      end
    end
  end
end
