# frozen_string_literal: true

require 'json'

module Engine
  module Game
    module G18IL
      module Bot
        class TournamentWorker
          def self.run(input)
            JSON.parse(input).map { |config| run_game(config) }
          end

          def self.run_game(config)
            profiles = config['profiles'].map { |profile| PolicyProfile.from_h(profile) }
            result = Bot.run(
              players: profiles.size,
              profiles: profiles,
              optional_rules: config['optional_rules'].map(&:to_sym),
              seed: config['seed'],
              max_actions: config['max_actions'],
            )
            summarize(result, config['seed'], config['rotation'], profiles)
          rescue StandardError => e
            {
              seed: config['seed'],
              rotation: config['rotation'] + 1,
              status: 'error',
              detail: "#{e.class}: #{e.message}",
              actions_taken: 0,
              seats: Array(profiles).map.with_index do |profile, index|
                { seat: index + 1, profile: profile.name }
              end,
              results: [],
              last_action: nil,
              backtrace: e.backtrace.first(20),
            }
          end

          def self.summarize(result, seed, rotation, profiles)
            game = result.game
            rankings = game.result.keys.each_with_index.to_h { |player_id, index| [player_id, index + 1] }
            results = profiles.map.with_index do |profile, index|
              player_id = "Bot #{index + 1}"
              player = game.players.find { |candidate| candidate.id == player_id }
              {
                profile: profile.name,
                seat: index + 1,
                rank: rankings[player_id],
                value: player && game.player_value(player),
              }
            end

            {
              seed: seed,
              rotation: rotation + 1,
              status: result.status.to_s,
              detail: result.detail,
              actions_taken: result.actions_taken,
              seats: profiles.map.with_index { |profile, index| { seat: index + 1, profile: profile.name } },
              results: results,
              last_action: result.trace.last,
              backtrace: result.error_backtrace,
            }
          end
        end
      end
    end
  end
end
