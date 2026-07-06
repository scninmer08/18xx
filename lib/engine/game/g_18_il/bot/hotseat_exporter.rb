# frozen_string_literal: true

require 'json'
unless RUBY_ENGINE == 'opal'
  require 'open3'
  require 'rbconfig'
end

module Engine
  module Game
    module G18IL
      module Bot
        class HotseatExporter
          attr_reader :result

          def initialize(result)
            @result = result
          end

          def write(path)
            data = to_h
            validate!(data)
            File.write(path, JSON.pretty_generate(data))
          end

          def to_h
            game = result.game
            players = game.players.sort_by { |player| bot_seat(player) }

            {
              id: "18il_bot_#{game.seed}",
              title: game.class.title,
              description: "18IL bot replay, seed #{game.seed}",
              players: players.map { |player| { id: player.id, name: player.name } },
              min_players: players.size,
              max_players: players.size,
              settings: {
                seed: game.seed,
                optional_rules: game.optional_rules,
              },
              status: 'active',
              actions: game.raw_actions,
            }
          end

          private

          def validate!(data)
            return validate_in_process!(data) if RUBY_ENGINE == 'opal' || !Process.respond_to?(:fork)

            2.times do
              result = validate_in_child(data)
              next unless result

              return if result[:valid]

              raise GameError, "Bot replay validation failed: #{result[:detail]}"
            end

            # A native Ruby crash cannot be rescued. The game itself completed and its raw
            # actions remain exportable, so do not discard the replay solely because both
            # isolated validation workers crashed.
            nil
          end

          def validate_in_child(data)
            validator = File.expand_path('replay_validator.rb', __dir__)
            stdout, _stderr, status = Open3.capture3(
              RbConfig.ruby,
              '-Ilib',
              validator,
              stdin_data: JSON.generate(data),
            )
            return unless status.success?

            JSON.parse(stdout, symbolize_names: true)
          rescue JSON::ParserError, SystemCallError
            nil
          end

          def validate_in_process!(data)
            game = result.game
            names = data[:players].to_h { |player| [player[:id], player[:name]] }
            replay = game.class.new(
              names,
              seed: data.dig(:settings, :seed),
              optional_rules: data.dig(:settings, :optional_rules),
              actions: data[:actions],
            )

            return if !replay.exception && replay.actions.size == data[:actions].size

            detail = replay.exception&.full_message ||
              "processed #{replay.actions.size} of #{data[:actions].size} actions"
            raise GameError, detail
          end

          def bot_seat(player)
            player.id.to_s[/\d+\z/].to_i
          end
        end
      end
    end
  end
end
