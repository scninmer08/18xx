# frozen_string_literal: true

# rubocop:disable Style/GlobalVars

if RUBY_ENGINE != 'opal' && File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__) &&
   !$g18_il_replay_validator_loading
  $g18_il_replay_validator_loading = true

  require 'json'
  require 'engine/logger'

  Engine::Logger.set_level(Logger::FATAL)
  require 'require_all'
  require_all 'lib/engine/game/g_18_il'

  data = JSON.parse($stdin.read)
  names = data.fetch('players').to_h { |player| [player.fetch('id'), player.fetch('name')] }
  game = Engine::Game::G18IL::Game.new(
    names,
    seed: data.dig('settings', 'seed'),
    optional_rules: data.dig('settings', 'optional_rules'),
    actions: data.fetch('actions'),
  )

  if !game.exception && game.actions.size == data.fetch('actions').size
    puts JSON.generate(valid: true)
  else
    detail = game.exception&.full_message ||
      "processed #{game.actions.size} of #{data.fetch('actions').size} actions"
    puts JSON.generate(valid: false, detail: detail)
  end
end

# rubocop:enable Style/GlobalVars
