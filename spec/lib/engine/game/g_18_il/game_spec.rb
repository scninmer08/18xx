# frozen_string_literal: true

require 'spec_helper'

module Engine
  describe Game::G18IL::Game do
    def packet_composition(packet)
      concessions = packet.select { |company| company.meta[:type] == :concession }
      [
        concessions.map { |company| company.meta[:share_count] }.sort.reverse,
        packet.count { |company| company.meta[:class] == :A },
        packet.count { |company| company.meta[:class] == :B },
      ]
    end

    def buy_train_step(game, corporation)
      round = double('round', entities: [corporation], entity_index: 0, bought_trains: [])
      step = Game::G18IL::Step::BuyTrain.new(game, round)
      step.setup
      step
    end

    def special_buy_step(game, corporation)
      round = double('round', entities: [corporation], entity_index: 0, active_step: nil)
      step = Game::G18IL::Step::SpecialBuy.new(game, round)
      step.setup
      step
    end

    def route_step(game, corporation)
      round = double('round', entities: [corporation], entity_index: 0)
      step = Game::G18IL::Step::Route.new(game, round)
      step.setup
      step
    end

    def special_token_step(game, company, corporation)
      round_class = Struct.new(:entities, :entity_index, :active_step, :tokened, :current_operator, :steps, :teleported) do
        def operating? = true
        def stock? = false
        def current_operator_acted = false
      end
      round = round_class.new([company], 0, nil, false, corporation, [], nil)
      step = Game::G18IL::Step::SpecialToken.new(game, round)
      round.active_step = step
      round.steps = [step]
      game.instance_variable_set(:@round, round)
      step.setup
      step
    end

    def graph_with_connected_nodes(nodes)
      double('graph').tap do |graph|
        allow(graph).to receive(:connected_nodes).and_return(nodes)
      end
    end

    def advance_depot_to_8_phase(game)
      %w[2 3 4 5 4+2C 5+1C].each { |name| game.depot.export_all!(name, silent: true) }
      game.depot.export!
    end

    def make_ic_presidented!(game, player = game.players.first)
      game.ic.presidents_share.buyable = true
      game.share_pool.transfer_shares(ShareBundle.new(game.ic.presidents_share), player)
      game.ic.owner = player
    end

    shared_examples 'packet auction setup' do |player_count, expected|
      it "builds the requested packets for #{player_count} players" do
        game = described_class.new(Array.new(player_count) { |index| "Player #{index + 1}" },
                                   optional_rules: [:packet_auction_variant])

        expect(game.lots.map { |packet| packet_composition(packet) }).to eq(expected)
        expect(game.lot_proxies.map(&:value)).to all(be_zero)
      end
    end

    include_examples 'packet auction setup', 3, [
      [[10, 5], 3, 1],
      [[10, 2], 2, 2],
      [[5, 5], 2, 2],
      [[5, 2], 1, 3],
    ]

    include_examples 'packet auction setup', 4, [
      [[10, 5], 3, 1],
      [[10, 2], 2, 2],
      [[5, 5], 2, 2],
      [[5, 2], 1, 3],
    ]

    include_examples 'packet auction setup', 5, [
      [[10, 5], 2, 0],
      [[10, 2], 1, 1],
      [[5, 5], 1, 1],
      [[5, 2], 0, 2],
      [[], 2, 2],
      [[], 2, 2],
    ]

    include_examples 'packet auction setup', 6, [
      [[10, 5], 2, 0],
      [[10, 2], 1, 1],
      [[5, 5], 1, 1],
      [[5, 2], 0, 2],
      [[], 2, 2],
      [[], 2, 2],
    ]

    context 'with one more packet than players' do
      let(:game) do
        described_class.new(%w[A B C], optional_rules: [:packet_auction_variant])
      end

      it 'returns the unselected contents to their pools' do
        game.resolve_big_lots_randomly!

        unselected = game.lots.find { |packet| packet.all? { |company| company.owner.nil? } }
        concessions = unselected.select { |company| company.meta[:type] == :concession }
        privates = unselected.select { |company| company.meta[:type] == :private }

        expect(concessions).not_to be_empty
        expect(privates).not_to be_empty
        expect(game.development_pool_privates).to include(*privates)
        expect(game.packet_auction_first_turn?).to be false
      end
    end

    it 'has four port permit spots with GTL and IC reserved' do
      game = described_class.new(%w[A B C D])
      city = game.hex_by_id(described_class::PORT_PERMIT_HEX).tile.cities.first

      expect(city.normal_slots).to eq(4)
      expect(city.reservations[0]).to eq(game.company_by_id('GTL'))
      expect(city.reservations[1]).to eq(game.ic)
    end

    it 'assigns a receivership operator for IC without marking that player as IC owner' do
      game = described_class.new(%w[A B C D])
      operator = game.players.first
      round = double('round', entities: [game.ic], active_entities: [game.ic])
      game.instance_variable_set(:@round, round)
      allow(game.players).to receive(:min_by).and_return(operator)

      game.assign_ic_operator!

      expect(game.ic_operator).to eq(operator)
      expect(game.ic.owner).to be_nil
      expect(game.ic.receivership?).to be true
      expect(game.acting_for_entity(game.ic)).to eq(operator)
      expect(game.active_players).to eq([operator])
      expect(game.valid_actors(double('action', entity: game.ic))).to eq([operator])
    end

    it 'still exposes run routes for IC while IC is in receivership' do
      game = described_class.new(%w[A B C D])
      train = game.depot.min_depot_train
      game.buy_train(game.ic, train, :free)
      step = route_step(game, game.ic)
      allow(game).to receive(:can_run_route?).with(game.ic).and_return(true)

      expect(game.ic.receivership?).to be true
      expect(step.actions(game.ic)).to eq(%w[run_routes])
    end

    it 'uses GTL for a port permit and optional Chicago token' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      gtl = game.company_by_id('GTL')
      gtl.owner = corporation
      corporation.companies << gtl
      step = special_token_step(game, gtl, corporation)
      city = game.hex_by_id(described_class::CHICAGO_HEX.first).tile.cities.find { |c| c.index == step.ability(gtl).city }

      expect(step.actions(gtl)).to contain_exactly('place_token', 'pass')

      step.process_place_token(Action::PlaceToken.new(gtl, city: city))

      expect(game.owns_port_permit?(corporation)).to be true
      expect(city.tokened_by?(corporation)).to be true
      expect(game.private_used?(gtl)).to be true
    end

    it 'uses GTL for only a port permit when a Chicago token cannot be placed' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      gtl = game.company_by_id('GTL')
      gtl.owner = corporation
      corporation.companies << gtl
      corporation.tokens.each { |token| token.used = true }
      step = special_token_step(game, gtl, corporation)

      expect(step.actions(gtl)).to eq(%w[pass])

      step.process_pass(Action::Pass.new(gtl))

      expect(game.owns_port_permit?(corporation)).to be true
      expect(game.private_used?(gtl)).to be true
    end

    it 'only exposes the port permit buy when the corporation has a route to Chicago' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      corporation.set_cash(100, game.bank)
      step = special_buy_step(game, corporation)
      chicago_city = game.hex_by_id(described_class::CHICAGO_HEX.first).tile.cities.first

      allow(game).to receive(:graph_for_entity)
        .with(corporation)
        .and_return(graph_with_connected_nodes({}))

      expect(step.buyable_items(corporation).map(&:description)).not_to include('Port Permit')

      allow(game).to receive(:graph_for_entity)
        .with(corporation)
        .and_return(graph_with_connected_nodes({ chicago_city => true }))

      expect(step.buyable_items(corporation).map(&:description)).to include('Port Permit')
    end

    it 'rejects buying a port permit without a route to Chicago' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      corporation.set_cash(100, game.bank)
      step = special_buy_step(game, corporation)

      allow(game).to receive(:graph_for_entity)
        .with(corporation)
        .and_return(graph_with_connected_nodes({}))

      expect do
        step.process_special_buy(Action::SpecialBuy.new(corporation, item: step.port_permit))
      end.to raise_error(GameError, /must have a route to Chicago/)
    end

    it 'removes port and STL permits when a corporation closes' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      corporation.owner = game.players.first

      game.assign_port_permit(corporation)
      game.assign_stl_permit(corporation)

      expect(game.owns_port_permit?(corporation)).to be true
      expect(game.stl_permit?(corporation)).to be true

      game.close_corporation(corporation)

      expect(game.owns_port_permit?(corporation)).to be false
      expect(game.stl_permit?(corporation)).to be false
    end

    it 'loans trainless IC the shortfall for the cheapest bank train' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      make_ic_presidented!(game)
      ic.set_cash(40, game.bank)

      step = buy_train_step(game, ic)

      train = game.depot.min_depot_train
      expect(game.ic_in_receivership?).to be false

      step.process_buy_train(Action::BuyTrain.new(ic, train: train, price: train.price))

      expect(ic.trains).to include(train)
      expect(ic.cash).to eq(0)
      expect(ic.loans.first.amount).to eq(40)
      expect(game.frozen_corporations).to include(ic)
    end

    it 'lets trainless non-receivership IC buy a train from another corporation at face value' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      other = game.corporation_by_id('IR')
      other_train = game.depot.min_depot_train
      game.buy_train(other, other_train, :free)
      make_ic_presidented!(game)
      ic.set_cash(other_train.price, game.bank)
      step = buy_train_step(game, ic)

      expect(game.ic_in_receivership?).to be false
      expect(step.buyable_trains(ic)).to include(other_train)

      step.process_buy_train(Action::BuyTrain.new(ic, train: other_train, price: other_train.price))

      expect(ic.trains).to include(other_train)
      expect(ic.cash).to eq(0)
      expect(other.cash).to eq(other_train.price)
    end

    it 'requires trainless non-receivership IC to pay face value for another corporation train' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      other = game.corporation_by_id('IR')
      other_train = game.depot.min_depot_train
      game.buy_train(other, other_train, :free)
      make_ic_presidented!(game)
      ic.set_cash(other_train.price, game.bank)
      step = buy_train_step(game, ic)

      expect do
        step.process_buy_train(Action::BuyTrain.new(ic, train: other_train, price: other_train.price - 1))
      end.to raise_error(GameError, /Must pay face value/)
    end

    it 'forces receivership IC with a train and room to buy the cheapest depot train it can afford' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      owned_train = game.depot.min_depot_train
      game.buy_train(ic, owned_train, :free)
      ic.set_cash(game.depot.min_depot_price, game.bank)
      step = buy_train_step(game, ic)

      train = game.depot.min_depot_train

      expect(game.ic_in_receivership?).to be true
      expect(step.actions(ic)).to eq(%w[buy_train])
      expect(step.buyable_trains(ic)).to eq([train])

      step.process_buy_train(Action::BuyTrain.new(ic, train: train, price: train.price))

      expect(ic.trains).to include(owned_train, train)
      expect(ic.cash).to eq(0)
    end

    it 'prevents receivership IC from buying trains from other corporations' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      other = game.corporation_by_id('IR')
      other_train = game.depot.min_depot_train
      game.buy_train(other, other_train, :free)
      ic.set_cash(500, game.bank)
      step = buy_train_step(game, ic)

      expect(game.ic_in_receivership?).to be true
      expect(step.buyable_trains(ic)).not_to include(other_train)

      expect do
        step.process_buy_train(Action::BuyTrain.new(ic, train: other_train, price: other_train.price))
      end.to raise_error(GameError, /only buy trains from the Depot/)
    end

    it 'forces receivership IC to upgrade to a D train when it cannot afford the cheapest depot train' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      advance_depot_to_8_phase(game)
      owned_train = game.depot.trains.find { |train| train.name == '4' }
      game.buy_train(ic, owned_train, :free)
      ic.set_cash(700, game.bank)
      step = buy_train_step(game, ic)

      d_train = game.depot.depot_trains.find { |train| train.name == 'D' }

      expect(game.depot.min_depot_train.name).to eq('8')
      expect(game.ic_in_receivership?).to be true
      expect(step.actions(ic)).to eq(%w[buy_train])
      expect(step.buyable_trains(ic)).to eq([])

      step.process_buy_train(Action::BuyTrain.new(ic, train: d_train, price: 700, exchange: owned_train))

      expect(ic.trains).to include(d_train)
      expect(ic.trains).not_to include(owned_train)
      expect(ic.cash).to eq(0)
    end

    it 'does not move IC share price when IC shares are sold during receivership' do
      game = described_class.new(%w[A B C D])
      player = game.players.first
      ic = game.ic
      game.stock_market.set_par(ic, game.stock_market.par_prices.find { |price| price.price == described_class::IC_STARTING_PRICE })
      ic.ipoed = true

      share = ic.shares_of(ic).reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      price = ic.share_price

      game.sell_shares_and_change_price(ShareBundle.new(share))

      expect(ic.share_price).to eq(price)
      expect(game.ic_in_receivership?).to be true
    end

    context 'when buying IC shares' do
      let(:game) { described_class.new(%w[A B C D]) }
      let(:president) { game.players[0] }
      let(:other_player) { game.players[1] }
      let(:seller) { game.corporation_by_id('IR') }
      let(:ic) { game.ic }
      let(:stock_step) { game.stock_round.steps.find { |step| step.is_a?(Game::G18IL::Step::BaseBuySellParShares) } }

      before do
        game.stock_market.set_par(seller, game.par_prices.first)
        game.stock_market.set_par(ic, game.stock_market.par_prices.find { |price| price.price == described_class::IC_STARTING_PRICE })
        seller.owner = president
        seller.ipoed = true
        ic.ipoed = true
      end

      it 'only lets the corporation president buy IC shares owned by that corporation' do
        share = ic.shares_of(ic).reject(&:president).first
        share.buyable = true
        game.share_pool.transfer_shares(ShareBundle.new(share), seller)

        expect(stock_step.can_gain?(president, share.to_bundle)).to be true
        expect(stock_step.can_gain?(other_player, share.to_bundle)).to be false
      end

      it 'lets any eligible player buy IC shares from the market' do
        share = ic.shares_of(ic).reject(&:president).first
        share.buyable = true
        game.share_pool.transfer_shares(ShareBundle.new(share), game.share_pool)

        expect(stock_step.can_gain?(other_player, share.to_bundle)).to be true
      end
    end
  end
end
