# frozen_string_literal: true

require 'spec_helper'

module Engine
  describe Game::G18FLOOD::Game do
    subject(:game) { described_class.new(%w[A B C], id: 18_001, seed: 1) }

    def start_national!(corporation = game.nationals.first, player = game.players.first)
      step = game.round.active_step
      step.instance_variable_set(:@auction_open, false)
      game.round.goto_entity!(player)
      par_price = game.par_prices(corporation).first
      step.process_par(Action::Par.new(player, corporation: corporation, share_price: par_price))
      corporation
    end

    def create_shell_with_pending_swap!(parent)
      game.instance_variable_set(:@round, game.operating_round(1))
      destination = game.hexes.find do |hex|
        hex.id != parent.coordinates && hex.tile.cities.any? { |city| city.tokenable?(parent) }
      end
      city = destination.tile.cities.find { |candidate| candidate.tokenable?(parent) }
      city.place_token(parent, parent.tokens.find { |token| !token.used })

      shell = game.create_shell_company(parent)
      game.par_and_sell_president_to_parent(shell, parent, 80)
      [shell, destination, city]
    end

    describe 'initial auction par validation' do
      let(:step) { game.round.active_step }
      let(:player) { game.players.first }
      let(:corporation) { game.nationals.first }

      before do
        step.instance_variable_set(:@auction_open, false)
        game.round.goto_entity!(player)
      end

      it 'rejects a corporation that is not available' do
        step.companies.delete(corporation)
        action = Action::Par.new(player, corporation: corporation, share_price: game.par_prices(corporation).first)

        expect { step.process_par(action) }.to raise_error(GameError, 'Corporation is not available to start')
      end

      it 'rejects a submitted par price other than the national starting price' do
        wrong_price = game.stock_market.market.flatten.compact.find do |price|
          price.price != described_class::NATIONAL_STARTING_PRICE
        end
        action = Action::Par.new(player, corporation: corporation, share_price: wrong_price)

        expect { step.process_par(action) }.to raise_error(GameError, /must start at/)
      end
    end

    describe '#flood_event!' do
      it 'lays a flood tile managed by the game tile collection' do
        ring = game.ring_for_flood_index(1)
        target = ring.map { |id| game.hex_by_id(id) }.find { |hex| hex.tile.name != 'FLOOD' }
        pool_flood_tile = game.tiles.find { |tile| tile.name == 'FLOOD' }
        game.instance_variable_set(:@flood_ring_index, 1)

        game.flood_event!

        expect(target.tile.name).to eq('FLOOD')
        expect(target.tile).to equal(pool_flood_tile)
      end

      it 'advances the default flood after every second completed OR' do
        allow(game).to receive(:flood_event!)

        game.advance_flood_clock!
        expect(game).not_to have_received(:flood_event!)

        game.advance_flood_clock!
        expect(game).to have_received(:flood_event!).once
      end
    end

    describe 'procedural map setup' do
      it 'produces the same seeded tiles and rotations for the same seed' do
        other_game = described_class.new(%w[A B C], id: 18_002, seed: 1)
        map_state = lambda do |current_game|
          current_game.hexes.to_h do |hex|
            [hex.id, [hex.tile.name, hex.tile.rotation, hex.tile.upgrades.map(&:cost)]]
          end
        end

        expect(map_state.call(other_game)).to eq(map_state.call(game))
      end


      it 'derives seeded green and brown costs from each hex base terrain cost' do
        seeded_green = game.hexes.select { |hex| %w[FLD21 FLD22].include?(hex.tile.name) }
        seeded_brown = game.hexes.select { |hex| hex.tile.name == 'FLD31' }

        expect(seeded_green).not_to be_empty
        expect(seeded_brown).not_to be_empty
        seeded_green.each do |hex|
          expect(hex.tile.upgrades.sum(&:cost)).to eq(game.terrain_cost_for(hex, :green))
        end
        seeded_brown.each do |hex|
          expect(hex.tile.upgrades.sum(&:cost)).to eq(game.terrain_cost_for(hex, :brown))
        end
      end

      it 'places lucrative brown cities on the outer playable ring and greens inland' do
        seeded_brown = game.hexes.select { |hex| hex.tile.name == 'FLD31' }
        seeded_green = game.hexes.select { |hex| %w[FLD21 FLD22].include?(hex.tile.name) }

        expect(seeded_brown.size).to eq(9)
        expect(seeded_green.size).to eq(16)
        expect(seeded_brown.map { |hex| game.geometric_ring(hex) }.uniq).to eq([6])
        expect(seeded_green.map { |hex| game.geometric_ring(hex) }.uniq.sort).to eq([2, 3, 4, 5])
      end

      it 'makes the former blank cities ordinary 240-cost terrain eligible for green cities' do
        Game::G18FLOOD::Map::INNER_PLAIN_HEXES.each do |id|
          hex = game.hex_by_id(id)
          expect(hex).not_to be_nil
          expect(%i[white green]).to include(hex.tile.color)
          expect(game.base_terrain_cost(hex)).to eq(240)
        end
      end

      it 'pre-lays simple track following the developed coastline' do
        coastal_track = game.hexes.select do |hex|
          %w[7 8 9].include?(hex.tile.name) && game.geometric_ring(hex) == 6
        end

        expect(coastal_track).not_to be_empty
        coastal_track.each do |hex|
          expect(hex.tile.upgrades.sum(&:cost)).to eq(game.terrain_cost_for(hex, :yellow))
          expect(game.coastal_track_spec(hex)).not_to be_nil
        end
        expect(game.ring_for_flood_index(6).none? do |id|
          game.blank_plain?(game.hex_by_id(id))
        end).to be(true)
      end

      it 'organizes inland green cities into three switchback corridors' do
        expect(game.city_corridor_sextants.size).to eq(3)
        expect(game.city_corridor_sextants.each_cons(2).map { |left, right| right - left }).to eq([2, 2])

        green_by_ring = game.hexes.select do |hex|
          %w[FLD21 FLD22].include?(hex.tile.name)
        end.group_by { |hex| game.geometric_ring(hex) }
        expected_offsets = Game::G18FLOOD::Game::CORRIDOR_SWITCHBACK_BY_RING
        expected_offsets.each do |ring, switchback|
          desired = game.city_corridor_sextants.map { |sextant| (sextant + switchback) % 6 }
          actual = green_by_ring.fetch(ring).map { |hex| game.sextant_index(game.center_hex_id, hex.id) }
          expect(actual & desired).not_to be_empty
        end
        expect(game.city_corridor_hexes.keys.sort).to eq([0, 1, 2])
        expect(game.city_corridor_hexes.values.flatten.size).to eq(16)
      end

      it 'orients corridor cities toward both the coast and center' do
        game.city_corridor_hexes.each do |corridor, ids|
          ids.each do |id|
            hex = game.hex_by_id(id)
            ring = game.geometric_ring(hex)
            required_edges = game.corridor_route_edges(hex, ring, corridor)
            expect(required_edges - hex.tile.exits).to be_empty
          end
        end
      end

      it 'uses the base, two-thirds, one-third, and one-sixth progression' do
        hexes_by_base = [60, 120, 240].to_h do |base|
          hex = game.hexes.find { |candidate| game.base_terrain_cost(candidate) == base }
          [base, hex]
        end

        expect(hexes_by_base.values).not_to include(nil)
        expect(hexes_by_base.transform_values { |hex| game.terrain_cost_for(hex, :yellow) }).to eq(
          60 => 40, 120 => 80, 240 => 160
        )
        expect(hexes_by_base.transform_values { |hex| game.terrain_cost_for(hex, :green) }).to eq(
          60 => 20, 120 => 40, 240 => 80
        )
        expect(hexes_by_base.transform_values { |hex| game.terrain_cost_for(hex, :brown) }).to eq(
          60 => 10, 120 => 20, 240 => 40
        )
      end

      it 'preserves the original generator as the symmetrical map variant' do
        symmetrical = described_class.new(
          %w[A B C],
          id: 18_003,
          seed: 1,
          optional_rules: [:symmetrical_map]
        )
        default_tiles = game.hexes.to_h { |hex| [hex.id, hex.tile.name] }
        symmetrical_tiles = symmetrical.hexes.to_h { |hex| [hex.id, hex.tile.name] }

        expect(symmetrical.symmetrical_map?).to be(true)
        expect(default_tiles).not_to eq(symmetrical_tiles)
        expect(symmetrical.hexes.size).to be > game.hexes.size
      end

      it 'limits the default playable map to a continuous radius 6' do
        mask = game.generated_shape_mask

        expect(mask).to include(*Game::G18FLOOD::Map::RADIUS7)
        expect(mask).to include(*Game::G18FLOOD::Map::RADIUS8)
        expect(mask).to include(*Game::G18FLOOD::Map::RADIUS9)
        expect(mask.size).to eq(
          (Game::G18FLOOD::Map::RADIUS7 + Game::G18FLOOD::Map::RADIUS8 + Game::G18FLOOD::Map::RADIUS9).uniq.size
        )
        expect(mask.all? { |id| !game.hex_by_id(id) || game.hex_by_id(id).tile.color == :blue }).to be(true)
      end


      it 'surrounds the playable perimeter with permanent water' do
        expect(game.outer_water_ring.size).to be >= 39
        expect(game.outer_water_ring.all? { |id| game.hex_by_id(id)&.tile&.color == :blue }).to be(true)
        expect(Game::G18FLOOD::Map::FORMER_HOME_HEXES.all? do |id|
          hex = game.hex_by_id(id)
          hex && hex.tile.color != :blue
        end).to be(true)
        expect(Game::G18FLOOD::Map::VERTEX_WATER_HEXES.all? do |id|
          game.hex_by_id(id)&.tile&.color == :blue
        end).to be(true)
      end

      it 'uses a six-ring flood clock on the default map' do
        game.compute_flood_rings!

        expect(game.instance_variable_get(:@max_flood_ring)).to eq(6)
        expect((0..6).all? { |ring| game.ring_for_flood_index(ring).any? }).to be(true)
      end

      it 'starts the default map without pre-existing flood water' do
        expect(game.hexes.none? { |hex| hex.tile.name == 'FLOOD' }).to be(true)
      end

      it 'randomizes mill locations away from cities' do
        expect(game.lumber_mills.size).to eq(3)
        expect(game.steel_mills.size).to eq(3)
        expect(game.lumber_mills).not_to eq(Game::G18FLOOD::Map::LUMBER_MILLS)
        (game.lumber_mills + game.steel_mills).each do |id|
          hex = game.hex_by_id(id)
          expect(hex.neighbors.values.compact.none? { |neighbor| neighbor.tile.cities.any? }).to be(true)
          other_mills = (game.lumber_mills + game.steel_mills) - [id]
          expect(hex.neighbors.values.compact.none? { |neighbor| other_mills.include?(neighbor.id) }).to be(true)
        end
      end

      it 'keeps generated cities and mills away from national homes' do
        occupied_ids = game.lumber_mills + game.steel_mills
        occupied_ids.concat(game.hexes.select do |hex|
          Game::G18FLOOD::Game::GENERATED_CITY_TILES.include?(hex.tile.name)
        end.map(&:id))

        Game::G18FLOOD::Map::HOME_HEXES.each do |home_id|
          neighbors = game.hex_by_id(home_id).neighbors.values.compact.map(&:id)
          expect(neighbors & occupied_ids).to be_empty
        end
      end

      it 'allows generated cities in pairs but prevents larger city clusters' do
        generated_city_names = %w[FLD21 FLD22 FLD31]
        generated_cities = game.hexes.select { |hex| generated_city_names.include?(hex.tile.name) }

        generated_cities.each do |hex|
          adjacent_cities = hex.neighbors.values.compact.select do |neighbor|
            generated_city_names.include?(neighbor.tile.name)
          end
          expect(adjacent_cities.size).to be <= 1
          adjacent_cities.each do |neighbor|
            expect(neighbor.neighbors.values.compact.count do |other|
              generated_city_names.include?(other.tile.name)
            end).to be <= 1
          end
        end
      end

      it 'uses fixed terrain costs by radius without terrain frames' do
        expected_costs = {
          1 => 240, 2 => 240,
          3 => 120, 4 => 120,
          5 => 60, 6 => 60,
        }
        expected_costs.each do |ring, cost|
          game.ring_for_flood_index(ring).each do |id|
            hex = game.hex_by_id(id)
            next if game.base_terrain_cost(hex).zero?

            expect(game.base_terrain_cost(hex)).to eq(cost)
            expect(hex.tile.frame).to be_nil unless hex.tile.partitions.any?
          end
        end
      end

      it 'keeps every national home connected to the center across seeds' do
        5.times do |seed|
          generated = described_class.new(%w[A B C], id: 18_100 + seed, seed: seed)
          center = generated.hex_by_id(generated.center_hex_id)

          generated.nationals.each do |national|
            start = generated.hex_by_id(national.coordinates)
            visited = { start.id => true }
            queue = [start]
            until queue.empty? || visited[center.id]
              hex = queue.shift
              hex.neighbors.values.compact.each do |neighbor|
                next if visited[neighbor.id] || neighbor.tile.name == 'FLOOD'

                visited[neighbor.id] = true
                queue << neighbor
              end
            end
            expect(visited).to include(center.id), "seed #{seed} isolates #{national.name}"
          end
        end
      end

      it 'places all national homes on ring 5' do
        game.compute_flood_rings!

        expect(game.nationals.map(&:coordinates)).to all(satisfy { |id| game.ring_for_flood_index(5).include?(id) })
      end
    end

    describe 'shell lifecycle' do
      let(:player) { game.players.first }
      let(:parent) { start_national! }

      it 'starts a national with the expected ownership and treasury cash' do
        expect(parent.owner).to equal(player)
        expect(player.percent_of(parent)).to eq(100)
        expect(parent.cash).to eq(Engine::Game::G18FLOOD::Step::InitAuction::SEED_AMOUNT)
        expect(parent.tokens.count(&:used)).to eq(1)
      end

      it 'pars a shell, transfers its president share, and queues a token swap' do
        parent
        shell, destination = create_shell_with_pending_swap!(parent)

        expect(game.shell_parent[shell]).to equal(parent)
        expect(shell.owner).to equal(parent)
        expect(parent.percent_of(shell)).to eq(50)
        expect(parent.cash).to eq(800)
        expect(shell.cash).to eq(400)
        expect(game.pending_shell).to be_nil
        expect(game.round.pending_tokens.last).to include(entity: shell, parent: parent)
        expect(game.round.pending_tokens.last[:hexes]).to include(destination)
      end

      it 'replaces the parent token and completes post-swap share buying in player order' do
        parent
        shell, _destination, city = create_shell_with_pending_swap!(parent)
        home_token_step = game.round.steps.find { |step| step.is_a?(Game::G18FLOOD::Step::HomeToken) }

        home_token_step.process_place_token(Action::PlaceToken.new(shell, city: city))

        expect(city.tokens.compact.map(&:corporation)).to include(shell)
        expect(city.tokens.compact.map(&:corporation)).not_to include(parent)
        expect(game.round.pending_tokens).to be_empty

        share_step = game.round.steps.find { |step| step.is_a?(Game::G18FLOOD::Step::ShellPostSwapShares) }
        expect(share_step.current_entity).to equal(player)

        3.times do
          share = share_step.find_buyable_share_for(player)
          share_step.process_buy_shares(Action::BuyShares.new(player, shares: share))
        end

        expect(player.percent_of(shell)).to eq(30)
        expect(shell.cash).to eq(640)
        expect(share_step.current_entity).to equal(game.players[1])

        share_step.process_pass(Action::Pass.new(game.players[1]))
        expect(share_step.current_entity).to equal(game.players[2])

        share_step.process_pass(Action::Pass.new(game.players[2]))
        expect(game.round.shell_ipo).to be_nil
      end
    end

    describe 'rulebook configuration' do
      it 'starts players with $1,200' do
        expect(game.players.map(&:cash)).to all(eq(1_200))
      end

      it 'offers every legal shell par price and no others' do
        expect(Game::G18FLOOD::Step::ParShell::PARS).to eq([80, 100, 120, 140, 160])
      end

      it 'does not make purple tiles available for normal track upgrades' do
        expect(game.phase.tiles).not_to include(:purple)

        gray = game.tiles.find { |tile| tile.name == 'FLDS4' }
        purple = game.tiles.find { |tile| tile.name == 'FLDS5' }
        expect(game.tile_valid_for_phase?(purple)).to be(false)
        expect(game.upgrades_to?(gray, purple)).to be(false)
      end

      it 'still allows the development fund to build the purple center tile' do
        game.lay_from_pool!(game.center_hex_id, 'FLDS4', 0)
        game.compute_center_stage!
        game.center_fund = 400

        game.maybe_auto_upgrade_center!

        expect(game.hex_by_id(game.center_hex_id).tile.name).to eq('FLDS5')
        expect(game.center_fund).to eq(0)
      end
    end

    describe 'national equity sale logging' do
      it 'describes sold national certificates as removed from the game' do
        corporation = start_national!
        player = game.players.first
        share = player.shares_of(corporation).find { |candidate| !candidate.president }

        game.share_pool.log_sell_shares(player, 'sells', share.to_bundle, 120, '')

        expect(game.log.last.message).to eq(
          "#{player.name} sells 1 equity certificate of #{corporation.name}; " \
          "the equity certificate is removed from the game and #{player.name} receives $120"
        )
      end
    end

    describe 'shell dividend share-price movement' do
      subject(:step) { Game::G18FLOOD::Step::Dividend.new(game, game.round) }

      let(:shell) do
        corporation = game.shells.first
        par = game.stock_market.par_prices.find { |price| price.price == 80 }
        game.stock_market.set_par(corporation, par)
        corporation.trains << game.depot.upcoming.first
        corporation
      end

      it 'moves left when a shell pays no dividend' do
        expect(step.share_price_change(shell, 0)).to eq(share_direction: :left, share_times: 1)
      end

      it 'does not move when the dividend is below the share price' do
        expect(step.share_price_change(shell, 79)).to eq({})
      end

      it 'moves right when the dividend equals or exceeds the share price' do
        expect(step.share_price_change(shell, 80)).to eq(share_direction: :right, share_times: 1)
      end
    end

    describe 'split resource hexes' do
      it 'recognizes the engine split partition type' do
        step = Game::G18FLOOD::Step::ResourceDelivery.new(game, game.round)
        tile = game.hex_by_id('K15').tile

        expect(tile.partitions.first.type).to eq(:split)
        expect(step.send(:split_halves, tile)).not_to be_nil
      end
    end
  end
end
