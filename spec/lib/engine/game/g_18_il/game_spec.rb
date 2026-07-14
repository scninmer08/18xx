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

    def buy_train_before_run_route_step(game, corporation)
      round = double(
        'round',
        entities: [corporation],
        entity_index: 0,
        current_operator: corporation,
        premature_trains_bought: [],
        bought_trains: [],
      )
      step = Game::G18IL::Step::BuyTrainBeforeRunRoute.new(game, round)
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

    def dividend_step(game, corporation)
      round = Struct.new(:entities, :entity_index, :round_num, :laid_hexes, :routes, :extra_revenue)
        .new([corporation], 0, 1, [], [], 0)
      step = Game::G18IL::Step::Dividend.new(game, round)
      step.setup
      step
    end

    def home_token_step(game, corporation)
      round_class = Struct.new(:pending_tokens) do
        def clear_cache!; end
      end
      round = round_class.new([])
      step = Game::G18IL::Step::HomeToken.new(game, round)
      game.instance_variable_set(:@round, round)
      game.place_home_token(corporation)
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

    def selection_auction_step(game)
      round_class = Struct.new(:entities, :entity_index) do
        def next_entity_index!
          self.entity_index = (entity_index + 1) % entities.size
        end

        def goto_entity!(entity)
          self.entity_index = entities.index(entity)
        end
      end
      round = round_class.new(game.players, 0)
      Game::G18IL::Step::SelectionAuction.new(game, round)
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

    def advance_depot_to_4_trains(game)
      %w[2 3].each { |name| game.depot.export_all!(name, silent: true) }
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
      [[10, 5], 2, 2],
      [[10, 2], 2, 2],
      [[5, 5], 2, 2],
      [[5, 2], 2, 2],
    ]

    include_examples 'packet auction setup', 4, [
      [[10, 5], 2, 2],
      [[10, 2], 2, 2],
      [[5, 5], 2, 2],
      [[5, 2], 2, 2],
    ]

    [5, 6].each do |player_count|
      it "does not enable packet auction for #{player_count} players" do
        game = described_class.new(Array.new(player_count) { |index| "Player #{index + 1}" },
                                   optional_rules: [:packet_auction_variant])

        expect(game.packet_auction_variant?).to be false
      end
    end

    it 'limits packet auction game creation to 4 players' do
      expect(Game::G18IL::Meta.max_players([:packet_auction_variant], 6)).to eq(4)
      expect(Game::G18IL::Meta.max_players([], 6)).to eq(6)
      expect(Game::G18IL::Meta.check_options([:packet_auction_variant], 2, 5)[:error])
        .to eq('Packet Auction Variant is only available for 2-4 players')
    end

    it 'does not duplicate cannot-bid logs for a player already out of an IC share auction' do
      game = described_class.new(%w[A B C D])
      step = selection_auction_step(game)
      share = game.company_by_id('IC1')
      bidder = game.players[1]
      outbid_player = game.players[0]
      outbid_player.set_cash(90, game.bank)

      bids = Hash.new { |h, k| h[k] = [] }
      bids[share] = [Action::Bid.new(bidder, company: share, price: 90)]
      step.instance_variable_set(:@bids, bids)
      step.instance_variable_set(:@auctioning, share)
      step.instance_variable_set(:@active_bidders, [bidder])

      message = "#{outbid_player.name} cannot bid $95 and is out of the auction for #{share.name}"
      game.log << message

      step.auto_pass_auction(outbid_player)

      expect(game.log.map(&:message).count(message)).to eq(1)
      expect(outbid_player.passed?).to be true
    end

    it 'does not eliminate a private-auction high bidder who cannot afford the next increment' do
      game = described_class.new(['Scott', 'Eligible', 'Low Cash 1', 'Low Cash 2'])
      step = selection_auction_step(game)
      company = game.company_by_id('RD')
      scott, eligible, *low_cash_players = game.players

      allow(game).to receive(:privates_in_auction_pool?).and_return(true)
      company.owner = nil
      scott.set_cash(10, game.bank)
      eligible.set_cash(20, game.bank)
      low_cash_players.each { |player| player.set_cash(10, game.bank) }
      eligible.pass!

      step.send(:setup_auction)
      step.instance_variable_set(:@companies, [company])
      step.process_bid(Action::Bid.new(scott, company: company, price: 10))

      expect(step.send(:auctioning)).to eq(company)
      expect(step.bids.fetch(company).map(&:entity)).to eq([scott])
      expect(step.current_entity).to eq(eligible)
      expect(game.log.map(&:message)).not_to include(
        'Scott cannot bid $15 and is out of the auction for Rush Delivery',
      )

      step.process_pass(Action::Pass.new(eligible))

      expect(company.owner).to eq(scott)
      expect(scott.cash).to eq(0)
      expect(game.log.map(&:message)).to include('Scott wins the auction for Rush Delivery with a bid of $10')
    end

    it 'allows a president to sell shares for a Rush Delivery emergency train buy' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('WAB')
      president = game.players.first
      rush_delivery = game.company_by_id('RD')
      corporation.owner = president
      rush_delivery.owner = corporation
      corporation.companies << rush_delivery unless corporation.companies.include?(rush_delivery)
      step = buy_train_before_run_route_step(game, corporation)

      allow(step).to receive(:president_may_contribute?).with(corporation).and_return(true)
      allow(step).to receive(:sellable_shares?).with(president).and_return(true)
      allow(step).to receive(:can_buy_train?).with(corporation).and_return(false)

      expect(step.actions(president)).to eq(%w[sell_shares])
      expect(step.actions(corporation)).to include('buy_train')
    end

    it 'logs a company owner when a private finishes the IC Line' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      advanced_track = game.company_by_id('AT')
      advanced_track.owner = corporation
      corporation.companies << advanced_track

      game.send(:trigger_ic_formation!, advanced_track)

      expect(game.log.map(&:message))
        .to include("-- The Illinois Central Railroad will form at the end of #{corporation.name}'s turn --")
      expect(game.log.map(&:message))
        .not_to include("-- The Illinois Central Railroad will form at the end of #{advanced_track.name}'s turn --")
    end

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

    it 'does not expose the port permit buy when the port permit slots are full' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('NC')
      corporation.set_cash(100, game.bank)
      gtl_owner = game.corporation_by_id('IR')
      gtl = game.company_by_id('GTL')
      gtl.owner = gtl_owner
      gtl_owner.companies << gtl

      [gtl_owner, game.ic, game.corporation_by_id('G&CU'), game.corporation_by_id('RI')].each do |corp|
        game.assign_port_permit(corp)
      end

      step = special_buy_step(game, corporation)
      chicago_city = game.hex_by_id(described_class::CHICAGO_HEX.first).tile.cities.first

      allow(game).to receive(:graph_for_entity)
        .with(corporation)
        .and_return(graph_with_connected_nodes({ chicago_city => true }))

      expect(game.port_permit_available?(corporation)).to be false
      expect(step.buyable_items(corporation).map(&:description)).not_to include('Port Permit')
      expect { game.assign_port_permit(corporation) }.to raise_error(GameError, /No port permit slot is available/)
    end

    it 'does not ask a reopened corporation for a second home after flipping an abandoned token' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('NC')
      city = game.hex_by_id('E12').tile.cities.first
      token = Token.new(corporation)
      corporation.tokens << token
      city.place_token(corporation, token, free: true, check_tokenable: false)
      token.status = :flipped
      game.closed_corporations << corporation

      step = home_token_step(game, corporation)

      expect(game.round.pending_tokens.size).to eq(1)

      step.process_place_token(Action::PlaceToken.new(corporation, city: city))
      game.closed_corporations.delete(corporation)
      game.place_home_token(corporation)

      expect(token.status).to be_nil
      expect(corporation.coordinates).to eq('E12')
      expect(game.round.pending_tokens).to be_empty
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
      expect(game.log.map(&:message))
        .to include("#{ic.name} buys a #{train.name} train for #{game.format_currency(train.price)} from The Depot")
    end

    it 'loans trainless IC the shortfall for the cheapest formation train' do
      game = described_class.new(%w[A B C D])
      ic = game.ic
      game.send(:ic_setup)
      ic.set_cash(40, game.bank)

      train = game.depot.min_depot_train
      expected_shortfall = train.price - ic.cash

      game.send(:buy_formation_train_for_ic!)

      expect(ic.trains).to include(train)
      expect(ic.cash).to eq(0)
      expect(ic.loans.first.amount).to eq(expected_shortfall)
      expect(game.frozen_corporations).to include(ic)
      expect(game.log.map(&:message))
        .to include("#{ic.name} buys a #{train.name} train for #{game.format_currency(train.price)} from The Depot")
    end

    it 'shows the 0+3C when 4 trains are available even if the corporation cannot afford it' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      game.buy_train(corporation, game.depot.min_depot_train, :free)
      advance_depot_to_4_trains(game)
      corporation.set_cash(300, game.bank)
      step = buy_train_step(game, corporation)

      train = game.depot.min_depot_train

      expect(train.name).to eq('4')
      expect(step.buyable_train_variants(train, corporation).map { |variant| variant[:name] }).to include('0+3C')

      expect do
        step.process_buy_train(Action::BuyTrain.new(corporation, train: train, price: 320, variant: '0+3C'))
      end.to raise_error(GameError, /cannot spend|has 300/)
    end

    it 'warns a trainless corporation to buy the cheapest train when it selects an unaffordable 0+3C' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('IR')
      advance_depot_to_4_trains(game)
      corporation.set_cash(300, game.bank)
      step = buy_train_step(game, corporation)

      train = game.depot.min_depot_train

      expect(train.name).to eq('4')
      expect(step.buyable_train_variants(train, corporation).map { |variant| variant[:name] }).to include('0+3C')

      expect do
        step.process_buy_train(Action::BuyTrain.new(corporation, train: train, price: 320, variant: '0+3C'))
      end.to raise_error(GameError, /cheaper train available \(4\)/)
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
      game.stock_market.set_par(ic, game.stock_market.par_prices.find do |price|
                                      price.price == described_class::IC_STARTING_PRICE
                                    end)
      ic.ipoed = true

      share = ic.shares_of(ic).reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      price = ic.share_price

      game.sell_shares_and_change_price(ShareBundle.new(share))

      expect(ic.share_price).to eq(price)
      expect(game.ic_in_receivership?).to be true
    end

    it 'does not move share price on the run that pays off a loan' do
      game = described_class.new(%w[A B C D])
      corporation = game.corporation_by_id('CBQ')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      corporation.loans << Loan.new(corporation, 100)
      game.frozen_corporations << corporation
      step = dividend_step(game, corporation)

      allow(step).to receive(:total_revenue).and_return(100)
      allow(step).to receive(:total_subsidy).and_return(0)

      price = corporation.share_price
      step.process_dividend(Action::Dividend.new(corporation, kind: 'withhold'))

      expect(corporation.loans).to be_empty
      expect(game.frozen_corporations).not_to include(corporation)
      expect(corporation.share_price).to eq(price)
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
        game.stock_market.set_par(ic, game.stock_market.par_prices.find do |price|
                                        price.price == described_class::IC_STARTING_PRICE
                                      end)
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

      it 'makes IC shares buyable when they are sold into the market' do
        share = ic.shares_of(ic).reject(&:president).first
        share.buyable = false
        game.share_pool.transfer_shares(ShareBundle.new(share), president)

        game.sell_shares_and_change_price(share.to_bundle)

        expect(share.owner).to eq(game.share_pool)
        expect(share.buyable).to be true
        expect(stock_step.can_buy_shares?(other_player, [share])).to be true
      end
    end
  end
end
