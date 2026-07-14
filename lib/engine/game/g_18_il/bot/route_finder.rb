# frozen_string_literal: true

require 'json'
require_relative '../../../auto_router'
require_relative '../../../action/run_routes'
unless RUBY_ENGINE == 'opal'
  require 'rbconfig'
  require 'tempfile'
end

module Engine
  module Game
    module G18IL
      module Bot
        class RouteFinder
          MAX_PATHS = 40
          MAX_STATES = 20_000
          ROUTE_LIMIT = 1_000
          LONG_ROUTE_LIMIT = 12_000
          LONG_BEAM_WIDTH = 2_000
          VALIDATION_LIMIT = 80
          LONG_VALIDATION_LIMIT = 800
          MAX_STOPS = 8
          MAX_LONG_ROUTE_STOPS = 32
          AUTO_PATH_TIMEOUT = 2
          AUTO_ROUTE_TIMEOUT = 1
          AUTO_ROUTE_LIMIT = 500
          LONG_ROUTE_TRAIN_NAMES = %w[4+2C 5 5+1C 5+2C 6 6+1C 8 9 D].freeze

          attr_reader :path_walk_timed_out, :route_search_timed_out, :rejections, :isolated_route_error

          def initialize(game)
            @game = game
            @rejections = Hash.new(0)
          end

          def best_route(corporation, train)
            routes_for(corporation, train, limit: 1).first
          end

          def maximum_routes(
            corporation,
            trains: nil,
            path_timeout: AUTO_PATH_TIMEOUT,
            route_timeout: AUTO_ROUTE_TIMEOUT,
            route_limit: AUTO_ROUTE_LIMIT
          )
            router = Engine::AutoRouter.new(@game)
            trains = Array(trains || @game.route_trains(corporation)).sort_by(&:price)
            train_routes, @path_walk_timed_out = router.path(
              trains,
              corporation,
              path_timeout: path_timeout,
              route_limit: route_limit,
            )
            maximum_route_combination(router, train_routes, route_timeout: route_timeout)
          end

          def isolated_maximum_routes(
            corporation,
            trains: nil,
            path_timeout: AUTO_PATH_TIMEOUT,
            route_timeout: AUTO_ROUTE_TIMEOUT,
            route_limit: AUTO_ROUTE_LIMIT,
            wall_timeout: path_timeout + route_timeout + 5
          )
            return if RUBY_ENGINE == 'opal' || !defined?(RbConfig)

            @isolated_route_error = nil
            payload = route_oracle_payload(corporation, Array(trains || @game.route_trains(corporation)),
                                           path_timeout, route_timeout, route_limit)
            result = run_route_oracle(payload, wall_timeout)
            return unless result&.fetch('ok', false)

            @path_walk_timed_out = result['path_walk_timed_out']
            @route_search_timed_out = result['route_search_timed_out']
            Engine::Action::RunRoutes.h_to_args(
              {
                'routes' => result.fetch('routes'),
                'extra_revenue' => 0,
                'subsidy' => 0,
              },
              @game,
            )[:routes]
          rescue StandardError => e
            @isolated_route_error = "#{e.class}: #{e.message}"
            nil
          end

          def timed_out?
            path_walk_timed_out || route_search_timed_out
          end

          def routes_for(corporation, train, limit: 20)
            connections = {}
            connections_to_evaluate = []
            all_paths = @game.hexes.flat_map { |hex| hex.tile.paths }
            adjacency = {}
            direct_routes = direct_spoke_routes(corporation, train, all_paths, adjacency)
            if long_train?(train)
              long_route_connections(corporation, all_paths, adjacency, connections, connections_to_evaluate)
            else
              route_connections(corporation, all_paths, adjacency, connections, connections_to_evaluate)
            end

            strongest_connections = connections_to_validate(connections_to_evaluate, train)
            routes = direct_routes + strongest_connections.filter_map { |connection| build_route(train, connection) }
            routes.uniq! { |route| route.paths.map(&:id).sort }
            routes.sort_by(&:revenue).reverse.take(limit)
          end

          private

          def maximum_route_combination(router, train_routes, route_timeout:)
            @route_search_timed_out = false
            candidates = train_routes.values.reverse
            return [] if candidates.empty?

            remaining_maximum = Array.new(candidates.size + 1, 0)
            (candidates.size - 1).downto(0) do |index|
              remaining_maximum[index] = remaining_maximum[index + 1] + candidates[index].first&.revenue.to_i
            end

            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + route_timeout
            best_routes = []
            best_revenue = 0
            search = lambda do |index, selected, bitfield, estimated_revenue|
              if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
                @route_search_timed_out = true
                return
              end
              return if estimated_revenue + remaining_maximum[index] <= best_revenue

              if index == candidates.size
                revenue = router.real_revenue(selected)
                if revenue > best_revenue
                  best_revenue = revenue
                  best_routes = selected.dup
                end
                return
              end

              candidates[index].each do |route|
                next if bitfield_conflict?(bitfield, route.bitfield)

                search.call(
                  index + 1,
                  selected + [route],
                  merge_bitfields(bitfield, route.bitfield),
                  estimated_revenue + route.revenue,
                )
              end
              search.call(index + 1, selected, bitfield, estimated_revenue)
            end
            search.call(0, [], [], 0)
            router.real_revenue(best_routes)
            best_routes
          end

          def route_oracle_payload(corporation, trains, path_timeout, route_timeout, route_limit)
            players = @game.players
              .sort_by { |player| player.id.to_s[/\d+\z/].to_i }
              .map { |player| { id: player.id, name: player.name } }
            {
              players: players,
              settings: {
                seed: @game.seed,
                optional_rules: @game.optional_rules,
              },
              actions: @game.raw_actions,
              corporation: corporation.id,
              train_ids: trains.map(&:id),
              path_timeout: path_timeout,
              route_timeout: route_timeout,
              route_limit: route_limit,
            }
          end

          def run_route_oracle(payload, wall_timeout)
            oracle = File.expand_path('route_oracle.rb', __dir__)
            stdin = Tempfile.new(['g18-il-route-oracle-in', '.json'])
            stdout = Tempfile.new(['g18-il-route-oracle-out', '.json'])
            stderr = Tempfile.new(['g18-il-route-oracle-err', '.log'])
            stdin.write(JSON.generate(payload))
            stdin.flush
            stdin.rewind
            pid = Process.spawn(RbConfig.ruby, '-Ilib', oracle, in: stdin.path, out: stdout.path, err: stderr.path)

            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + wall_timeout
            status = nil
            loop do
              _waited_pid, status = Process.waitpid2(pid, Process::WNOHANG)
              break if status

              if Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
                sleep 0.1
                next
              end

              @isolated_route_error = "route oracle timed out after #{wall_timeout}s"
              kill_route_oracle(pid)
              wait_for_route_oracle(pid)
              return nil
            end

            output = File.read(stdout.path)
            error = File.read(stderr.path)
            unless status.success?
              exit_detail = status.signaled? ? "signaled #{status.termsig}" : "exited #{status.exitstatus}"
              @isolated_route_error = error.to_s.lines.first&.strip || "route oracle #{exit_detail}"
              return nil
            end

            JSON.parse(output)
          rescue JSON::ParserError => e
            @isolated_route_error = "route oracle returned invalid JSON: #{e.message}"
            nil
          rescue StandardError => e
            @isolated_route_error = "#{e.class}: #{e.message}"
            nil
          ensure
            [stdin, stdout, stderr].compact.each do |io|
              io.close unless io.closed?
              io.unlink if io.respond_to?(:unlink)
            rescue StandardError
              nil
            end
          end

          def wait_for_route_oracle(pid)
            Process.waitpid2(pid)
          rescue Errno::ECHILD
            nil
          end

          def kill_route_oracle(pid)
            Process.kill('TERM', pid)
            sleep 0.2
            Process.kill('KILL', pid)
          rescue Errno::ESRCH, Errno::EPERM
            nil
          end

          def bitfield_conflict?(left, right)
            [left.size, right.size].min.times.any? { |index| (left[index] & right[index]) != 0 }
          end

          def merge_bitfields(left, right)
            Array.new([left.size, right.size].max) { |index| left[index].to_i | right[index].to_i }
          end

          def starting_paths(corporation)
            corporation.tokens.filter_map(&:city).uniq.flat_map(&:paths).uniq
          end

          def neighboring_paths(path, corporation, all_paths, adjacency)
            adjacency[path] ||= all_paths.select do |candidate|
              candidate != path && path.connects_to?(candidate, corporation)
            end
          end

          def route_connections(corporation, all_paths, adjacency, connections, connections_to_evaluate)
            queue = starting_paths(corporation).map { |path| [[path], [path.id]] }
            queue_index = 0

            while queue_index < queue.size && queue_index < MAX_STATES && connections_to_evaluate.size < ROUTE_LIMIT
              paths, visited = queue[queue_index]
              queue_index += 1
              add_connection(paths, connections, connections_to_evaluate)
              next if paths.size >= MAX_PATHS

              neighboring_paths(paths.last, corporation, all_paths, adjacency).each do |neighbor|
                next if visited.include?(neighbor.id)

                # Keep queued traversal state immutable. Some engine graph operations freeze
                # shared metadata, so a fresh array avoids Hash copy/update behavior entirely.
                queue << [paths + [neighbor], visited + [neighbor.id]]
              end
            end
          end

          def long_route_connections(corporation, all_paths, adjacency, connections, connections_to_evaluate)
            queue = starting_paths(corporation).map { |path| [[path], [path.id]] }
            states = 0

            until queue.empty? || states >= MAX_STATES || connections_to_evaluate.size >= LONG_ROUTE_LIMIT
              next_queue = []
              queue.each do |paths, visited|
                states += 1
                add_connection(paths, connections, connections_to_evaluate)
                next if paths.size >= MAX_PATHS

                neighboring_paths(paths.last, corporation, all_paths, adjacency).each do |neighbor|
                  next if visited.include?(neighbor.id)

                  next_queue << [paths + [neighbor], visited + [neighbor.id]]
                end
                break if states >= MAX_STATES || connections_to_evaluate.size >= LONG_ROUTE_LIMIT
              end
              queue = next_queue
                .sort_by { |paths, _visited| [-long_state_score(paths), paths.size] }
                .take(LONG_BEAM_WIDTH)
            end
          end

          def long_state_score(paths)
            connection = connection_for(paths)
            (estimated_revenue(connection) * 10) + (connection_stop_count(connection) * 20) + paths.size
          end

          def direct_spoke_routes(corporation, train, all_paths, adjacency)
            starting_paths(corporation).filter_map do |path|
              neighboring_paths(path, corporation, all_paths, adjacency).filter_map do |neighbor|
                next if neighbor.hex == path.hex
                next if neighbor.nodes.compact.empty?

                build_route(train, connection_for([path, neighbor]))
              end
            end.flatten
          end

          def add_connection(paths, connections, connections_to_evaluate)
            connection = connection_for(paths)
            return if connection.empty?

            path_groups = connection.map { |segment| segment.dig(:chain, :paths) }
            return if path_groups.any?(&:nil?)

            id = path_groups.flatten.map(&:id).sort
            return if connections[id]

            endpoints = connection.flat_map { |segment| [segment[:left], segment[:right]] }.compact.uniq
            return if endpoints.size < 2

            connections[id] = true
            connections_to_evaluate << connection
          end

          def connections_to_validate(connections, train)
            limit = long_train?(train) ? LONG_VALIDATION_LIMIT : VALIDATION_LIMIT
            strongest = connections
              .sort_by { |connection| [-estimated_revenue(connection), -connection_stop_count(connection)] }
              .take(limit)
            shortest = connections
              .sort_by { |connection| [connection_path_count(connection), -estimated_revenue(connection)] }
              .take(limit)
            early = connections.take(limit)
            return (strongest + shortest + early).uniq unless long_train?(train)

            longest = connections
              .sort_by { |connection| [-connection_stop_count(connection), -estimated_revenue(connection)] }
              .take(limit / 2)
            (strongest + shortest + early + longest).uniq
          end

          def estimated_revenue(connection)
            connection
              .flat_map { |segment| [segment[:left], segment[:right]] }
              .compact
              .uniq
              .sum(&:max_revenue)
          end

          def connection_stop_count(connection)
            connection.flat_map { |segment| [segment[:left], segment[:right]] }.compact.uniq.size
          end

          def connection_path_count(connection)
            connection.sum { |segment| segment[:chain][:paths].size }
          end

          def build_route(train, connection)
            return if connection_reuses_city?(train, connection)

            stops = connection.flat_map { |segment| [segment[:left], segment[:right]] }.compact.uniq
            return if stops.size > route_stop_limit(train, stops)

            route = Engine::Route.new(@game, @game.phase, train, connection_data: clone_connection_data(connection))
            route.routes = [route]
            paid_stops = paid_stops(route, train, stops)
            return if paid_stops.empty?

            route.instance_variable_set(:@stops, paid_stops)
            route.revenue(suppress_check_route_combination: true)
            route
          rescue Engine::GameError => e
            @rejections[[e.class.name, e.message]] += 1
            nil
          end

          def connection_reuses_city?(train, connection)
            return false if train.respond_to?(:local?) && train.local? &&
              connection.one? &&
              connection[0][:left] == connection[0][:right]

            cycles = {}
            connection.any? do |segment|
              left = segment[:left]
              right = segment[:right]
              cycles[left] = true if left
              reused = right && cycles[right]
              cycles[right] = true if right
              reused
            end
          end

          def paid_stops(route, train, visits)
            distance = train.distance
            return visits if distance.is_a?(Numeric)

            simple = simple_unlimited_plus_limited_distance(distance)
            return simple_paid_stops(route, train, visits, simple) if simple

            distance = distance.sort_by { |row| row['nodes'].size }
            max_stops = [distance.sum { |row| row['pay'].to_i }, visits.size].min
            max_stops.downto(1) do |count|
              candidates = visits.combination(count).filter_map do |stops|
                next if train.requires_token && stops.none? { |stop| @game.city_tokened_by?(stop, route.corporation) }
                next unless stops_fit_distance?(stops, train, distance)

                route.instance_variable_set(:@stops, stops)
                [stops, @game.revenue_for(route, stops)]
              end
              best = candidates.max_by(&:last)
              return best.first if best&.last&.positive?
            end
            []
          end

          def route_stop_limit(train, stops)
            distance = train.distance
            return [distance, MAX_LONG_ROUTE_STOPS].min if distance.is_a?(Numeric)

            simple = simple_unlimited_plus_limited_distance(distance)
            return MAX_STOPS unless simple

            unlimited, limited = simple
            unlimited_count = stops.count { |stop| unlimited['nodes'].include?(@game.stop_type(stop, train)) }
            [unlimited_count + limited['visit'].to_i, MAX_LONG_ROUTE_STOPS].min
          end

          def long_train?(train)
            distance = train.distance
            return true if train.respond_to?(:name) && LONG_ROUTE_TRAIN_NAMES.include?(train.name)
            return distance.to_i >= 5 if distance.is_a?(Numeric)

            simple = simple_unlimited_plus_limited_distance(distance)
            return false unless simple

            _unlimited, limited = simple
            limited['visit'].to_i >= 5
          end

          def simple_unlimited_plus_limited_distance(distance)
            return unless distance.size == 2

            unlimited = distance.find { |row| row['visit'].to_i >= MAX_LONG_ROUTE_STOPS }
            limited = (distance - [unlimited]).first if unlimited
            return unless unlimited && limited
            return unless (unlimited['nodes'] & limited['nodes']).empty?

            [unlimited, limited]
          end

          def simple_paid_stops(route, train, visits, distance)
            unlimited, limited = distance
            unlimited_stops = visits.select { |stop| unlimited['nodes'].include?(@game.stop_type(stop, train)) }
            limited_stops = visits.select { |stop| limited['nodes'].include?(@game.stop_type(stop, train)) }
            return [] if visits.size != unlimited_stops.size + limited_stops.size

            paid_limited = limited_stops
              .sort_by { |stop| -@game.revenue_for(route, [stop]) }
              .take(limited['pay'].to_i)
            paid = unlimited_stops + paid_limited
            return [] if train.requires_token && paid.none? { |stop| @game.city_tokened_by?(stop, route.corporation) }

            paid
          end

          def stops_fit_distance?(stops, train, distance)
            types_used = Array.new(distance.size, 0)
            stops.all? do |stop|
              row = distance.each_index.find do |index|
                distance[index]['nodes'].include?(@game.stop_type(stop, train)) &&
                  types_used[index] < distance[index]['pay']
              end
              types_used[row] += 1 if row
              row
            end
          end

          def clone_connection_data(connection)
            connection.map { |segment| clone_connection_value(segment) }
          end

          def clone_connection_value(value)
            case value
            when Array
              value.map { |entry| clone_connection_value(entry) }
            when Hash
              value.transform_values { |entry| clone_connection_value(entry) }
            else
              value
            end
          end

          def connection_for(paths)
            chains = []
            chain = []
            left = nil
            right = nil
            last_left = nil
            last_right = nil

            complete = lambda do
              chains << { nodes: [left, right], paths: chain, hexes: chain.map(&:hex) }
              last_left = left
              last_right = right
              left = nil
              right = nil
              chain = []
            end

            paths.each do |path|
              chain << path
              a, b = path.nodes
              next if !a && !b

              if a && b
                if a == last_left || b == last_right
                  left = b
                  right = a
                else
                  left = a
                  right = b
                end
                complete.call
              elsif !left
                left = a || b
              elsif !right
                right = a || b
                complete.call
              end
            end

            return [] if chains.empty?

            chains.map do |candidate|
              {
                left: candidate[:nodes][0],
                right: candidate[:nodes][1],
                chain: candidate,
              }
            end
          end
        end
      end
    end
  end
end
