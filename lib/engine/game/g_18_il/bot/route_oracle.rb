# frozen_string_literal: true

# rubocop:disable Style/GlobalVars

if RUBY_ENGINE != 'opal' && File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__) &&
   !$g18_il_route_oracle_loading
  $g18_il_route_oracle_loading = true

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

  raise game.exception.full_message if game.exception

  corporation = game.corporation_by_id(data.fetch('corporation'))
  trains = data.fetch('train_ids').map { |id| game.train_by_id(id) }
  finder = Engine::Game::G18IL::Bot::RouteFinder.new(game)
  routes = finder.maximum_routes(
    corporation,
    trains: trains,
    path_timeout: data.fetch('path_timeout'),
    route_timeout: data.fetch('route_timeout'),
    route_limit: data.fetch('route_limit'),
  )
  action = Engine::Action::RunRoutes.new(corporation, routes: routes)

  puts JSON.generate(
    ok: true,
    path_walk_timed_out: finder.path_walk_timed_out,
    route_search_timed_out: finder.route_search_timed_out,
    revenue: game.routes_revenue(routes),
    routes: action.args_to_h.fetch('routes'),
  )
end

# rubocop:enable Style/GlobalVars
