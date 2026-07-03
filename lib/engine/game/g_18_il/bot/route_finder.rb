# frozen_string_literal: true

require_relative '../../../auto_router'

module Engine
  module Game
    module G18IL
      module Bot
        class RouteFinder
          MAX_PATHS = 20
          MAX_STATES = 2_000
          ROUTE_LIMIT = 100
          VALIDATION_LIMIT = 8
          MAX_STOPS = 8
          AUTO_PATH_TIMEOUT = 2
          AUTO_ROUTE_TIMEOUT = 1
          AUTO_ROUTE_LIMIT = 500

          attr_reader :rejections

          def initialize(game)
            @game = game
            @rejections = Hash.new(0)
          end

          def best_route(corporation, train)
            routes_for(corporation, train, limit: 1).first
          end

          def maximum_routes(corporation)
            router = Engine::AutoRouter.new(@game)
            trains = @game.route_trains(corporation).sort_by(&:price)
            train_routes, = router.path(
              trains,
              corporation,
              path_timeout: AUTO_PATH_TIMEOUT,
              route_limit: AUTO_ROUTE_LIMIT,
            )
            maximum_route_combination(router, train_routes)
          end

          def routes_for(corporation, train, limit: 20)
            connections = {}
            connections_to_evaluate = []
            all_paths = @game.hexes.flat_map { |hex| hex.tile.paths }
            adjacency = {}
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

            strongest_connections = connections_to_evaluate
              .sort_by { |connection| -estimated_revenue(connection) }
              .take(VALIDATION_LIMIT)
            routes = strongest_connections.filter_map { |connection| build_route(train, connection) }
            routes.sort_by(&:revenue).reverse.take(limit)
          end

          private

          def maximum_route_combination(router, train_routes)
            candidates = train_routes.values.reverse
            return [] if candidates.empty?

            remaining_maximum = Array.new(candidates.size + 1, 0)
            (candidates.size - 1).downto(0) do |index|
              remaining_maximum[index] = remaining_maximum[index + 1] + candidates[index].first&.revenue.to_i
            end

            deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + AUTO_ROUTE_TIMEOUT
            best_routes = []
            best_revenue = 0
            search = lambda do |index, selected, bitfield, estimated_revenue|
              return if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
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

          def estimated_revenue(connection)
            connection
              .flat_map { |segment| [segment[:left], segment[:right]] }
              .compact
              .uniq
              .sum(&:max_revenue)
          end

          def build_route(train, connection)
            stops = connection.flat_map { |segment| [segment[:left], segment[:right]] }.compact.uniq
            return if stops.size > MAX_STOPS

            route = Engine::Route.new(@game, @game.phase, train, connection_data: connection.clone)
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

          def paid_stops(route, train, visits)
            distance = train.distance
            return visits if distance.is_a?(Numeric)

            distance = distance.sort_by { |row| row['nodes'].size }
            max_stops = [distance.sum { |row| row['pay'].to_i }, visits.size].min
            max_stops.downto(1) do |count|
              candidates = visits.combination(count).filter_map do |stops|
                next if train.requires_token && stops.none? { |stop| stop.tokened_by?(route.corporation) }
                next unless stops_fit_distance?(stops, train, distance)

                route.instance_variable_set(:@stops, stops)
                [stops, @game.revenue_for(route, stops)]
              end
              best = candidates.max_by(&:last)
              return best.first if best&.last&.positive?
            end
            []
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
