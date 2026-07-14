# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../../../lib/engine/game/g_18_il/bot/baseline_policy'

module Engine
  describe Game::G18IL::Bot::BaselinePolicy do
    let(:game) { Game::G18IL::Game.new(%w[A B C D]) }
    let(:player) { game.players.first }
    let(:policy) { described_class.new }
    let(:private_company) { game.company_by_id('GTL') }

    def with_exact_route_mode(value)
      previous = ENV.fetch('G18_IL_BOT_EXACT_ROUTES', nil)
      ENV['G18_IL_BOT_EXACT_ROUTES'] = value
      yield
    ensure
      if previous
        ENV['G18_IL_BOT_EXACT_ROUTES'] = previous
      else
        ENV.delete('G18_IL_BOT_EXACT_ROUTES')
      end
    end

    it 'does not open auctions for privates without a corporation that can eventually acquire them' do
      expect(policy.send(:auction_startable?, game, player, private_company)).to be false
    end

    it 'hands a Rush Delivery emergency share sale to the corporation president' do
      corporation = game.corporation_by_id('WAB')
      corporation.owner = player
      step = Game::G18IL::Step::BuyTrainBeforeRunRoute.allocate
      allow(step).to receive(:must_buy_train?).with(corporation).and_return(false)
      allow(step).to receive(:actions).with(player).and_return(%w[sell_shares])

      expect(policy.send(:decision_entity, corporation, step)).to eq(player)
    end

    it 'finishes a Rush Delivery emergency train buy after the president sells shares' do
      corporation = game.corporation_by_id('IR')
      corporation.owner = player
      corporation.set_cash(40, game.bank)
      player.set_cash(40, game.bank)
      train = game.depot.min_depot_train
      step = Game::G18IL::Step::BuyTrainBeforeRunRoute.allocate
      allow(game).to receive(:turn).and_return(5)
      allow(step).to receive(:buyable_trains).with(corporation).and_return([train])
      allow(step).to receive(:train_variant_helper).with(train, corporation).and_return(train.variants.values)
      allow(policy).to receive(:train_candidate_score).and_return(0)

      decision = policy.send(:train_decision, game, step, corporation, %w[buy_train])

      expect(decision.action).to be_a(Engine::Action::BuyTrain)
      expect(decision.action.train).to eq(train)
      expect(decision.action.price).to eq(80)
      expect(decision.reason).to include('cheapest emergency')
    end

    it 'can price-enforce unneeded privates for less than their normal value' do
      value = policy.send(:auction_item_value, game, player, private_company)

      expect(value).to be_between(1, described_class::PRIVATE_VALUES.fetch(private_company.id) - 1)
    end

    it 'opens auctions for privates that can eventually be acquired by an owned concession corporation' do
      concession = game.company_by_id('IR')
      concession.owner = player
      player.companies << concession

      expect(policy.send(:auction_startable?, game, player, private_company)).to be true
    end

    it 'does not open another same-class private auction when controlled corporations have no slots left' do
      concession = game.company_by_id('WAB')
      corporation = game.corporation_by_id('WAB')
      owned_private = game.company_by_id('ICC')
      game.companies.each { |company| company.owner = nil if company.meta[:type] == :private && company.owner == corporation }
      concession.owner = player
      owned_private.owner = player
      player.companies.concat([concession, owned_private])

      expect(policy.send(:auction_startable?, game, player, private_company)).to be false
    end

    it 'still opens a different private class auction when a controlled corporation has that slot left' do
      concession = game.company_by_id('WAB')
      corporation = game.corporation_by_id('WAB')
      owned_private = game.company_by_id('ICC')
      class_b_private = game.company_by_id('AT')
      game.companies.each { |company| company.owner = nil if company.meta[:type] == :private && company.owner == corporation }
      concession.owner = player
      owned_private.owner = player
      player.companies.concat([concession, owned_private])

      expect(policy.send(:auction_startable?, game, player, class_b_private)).to be true
    end

    it 'opens another same-class private auction when another controlled corporation can still acquire it' do
      wab = game.company_by_id('WAB')
      c_ei = game.company_by_id('C&EI')
      wab_corporation = game.corporation_by_id('WAB')
      c_ei_corporation = game.corporation_by_id('C&EI')
      owned_private = game.company_by_id('ICC')
      [wab_corporation, c_ei_corporation].each do |corporation|
        game.companies.each { |company| company.owner = nil if company.meta[:type] == :private && company.owner == corporation }
      end
      wab.owner = player
      c_ei.owner = player
      owned_private.owner = player
      player.companies.concat([wab, c_ei, owned_private])

      expect(policy.send(:auction_startable?, game, player, private_company)).to be true
    end

    it 'keeps initial private values grounded in direct ability impact' do
      corporation = game.corporation_by_id('WAB')
      values = %w[AT CIB CVCC EC EM FWC GTL ICC ISBC PO RD RE SP TS USML USY].to_h do |id|
        [id, policy.send(:private_value_for_corporation, game, corporation, game.company_by_id(id))]
      end

      expect(values).to eq(
        'AT' => 70,
        'CIB' => 10,
        'CVCC' => 46,
        'EC' => 50,
        'EM' => 70,
        'FWC' => 55,
        'GTL' => 75,
        'ICC' => 45,
        'ISBC' => 40,
        'PO' => 20,
        'RD' => 35,
        'RE' => 85,
        'SP' => 30,
        'TS' => 45,
        'USML' => 55,
        'USY' => 50,
      )
      expect(values.fetch('RE')).to be > values.fetch('TS')
      expect(values.fetch('RE')).to be > values.fetch('RD')
      expect(values.fetch('ICC')).to be < values.fetch('GTL')
    end

    it 'values geography-sensitive B privates by corporation fit' do
      fwc = game.company_by_id('FWC')
      cvcc = game.company_by_id('CVCC')
      isbc = game.company_by_id('ISBC')

      expect(policy.send(:private_value_for_corporation, game, game.corporation_by_id('RI'), fwc))
        .to be > policy.send(:private_value_for_corporation, game, game.corporation_by_id('WAB'), fwc)
      expect(policy.send(:private_value_for_corporation, game, game.corporation_by_id('IR'), cvcc))
        .to be > policy.send(:private_value_for_corporation, game, game.corporation_by_id('WAB'), cvcc)
      expect(policy.send(:private_value_for_corporation, game, game.corporation_by_id('V'), isbc))
        .to be > policy.send(:private_value_for_corporation, game, game.corporation_by_id('WAB'), isbc)
    end

    it 'adds FWC two-corporation synergy when the paired corporation is near Galena' do
      wab = game.corporation_by_id('WAB')
      ri = game.corporation_by_id('RI')
      fwc = game.company_by_id('FWC')
      fwc.owner&.companies&.delete(fwc)
      fwc.owner = wab
      wab.companies << fwc

      expect(policy.send(:galena_private_pair_synergy, [wab, ri])).to eq(25)
      expect(policy.send(:galena_private_pair_synergy, [wab, game.corporation_by_id('C&EI')])).to eq(0)
    end

    it 'raises timing-sensitive privates only when the board state supports them' do
      corporation = game.corporation_by_id('CBQ')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      corporation.ipoed = true
      phase = Struct.new(:name, :tiles).new('8', %i[yellow green brown gray])
      allow(game).to receive(:phase).and_return(phase)
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return({ name: 'D', price: 700 })
      allow(policy).to receive(:permanent_train_options)
        .with(game, corporation)
        .and_return([{ name: 'D', price: 700 }])
      allow(policy).to receive(:permanent_train_near?).with(game).and_return(true)
      allow(policy).to receive(:connected_route_groups).with(game, corporation).and_return(%w[East])

      expect(policy.send(:private_value_for_corporation, game, corporation, game.company_by_id('CIB'))).to eq(110)
      expect(policy.send(:private_value_for_corporation, game, corporation, game.company_by_id('TS'))).to eq(150)
      expect(policy.send(:private_value_for_corporation, game, corporation, game.company_by_id('RD'))).to eq(115)
      expect(policy.send(:private_value_for_corporation, game, corporation, game.company_by_id('SP'))).to eq(100)
      expect(policy.send(:private_value_for_corporation, game, corporation, game.company_by_id('ICC'))).to eq(80)
    end

    it 'values Rush Delivery higher when it can buy an affordable permanent before running' do
      corporation = game.corporation_by_id('CBQ')
      corporation.ipoed = true
      corporation.set_cash(700, game.bank)
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new('D', nil)
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return({ name: 'D', price: 700 })
      allow(policy).to receive(:permanent_train_options)
        .with(game, corporation)
        .and_return([{ name: 'D', price: 700 }])

      expect(policy.send(:private_value_for_corporation, game, corporation, game.company_by_id('RD')))
        .to eq(described_class::PRIVATE_VALUES.fetch('RD') + described_class::RUSH_DELIVERY_IMMEDIATE_PERMANENT_BONUS)
    end

    it 'activates Share Premium when it bridges a permanent train purchase' do
      corporation = game.corporation_by_id('CBQ')
      company = game.company_by_id('SP')
      company.owner = corporation
      corporation.ipoed = true
      corporation.set_cash(500, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      allow(policy).to receive(:permanent_train_options)
        .with(game, corporation)
        .and_return([{ name: 'D', price: 700 }])

      step = Object.new
      step.define_singleton_method(:choices_ability) { |_candidate| { 'sp_on' => 'Activate' } }

      decision = policy.send(:share_premium_decision, game, step, company)

      expect(decision.action).to be_a(Engine::Action::ChooseAbility)
      expect(decision.reason).to include('train-funding share')
    end

    it 'values Share Premium by train timing when it bridges a permanent below the normal high-price threshold' do
      corporation = game.corporation_by_id('CBQ')
      company = game.company_by_id('SP')
      corporation.ipoed = true
      corporation.set_cash(540, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      allow(policy).to receive(:permanent_train_options)
        .with(game, corporation)
        .and_return([{ name: 'D', price: 700 }])

      expect(policy.send(:private_value_for_corporation, game, corporation, company)).to eq(80)
    end

    it 'saves Share Premium when a normal issue already funds the permanent with buffer' do
      corporation = game.corporation_by_id('CBQ')
      company = game.company_by_id('SP')
      company.owner = corporation
      corporation.ipoed = true
      corporation.set_cash(700, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      allow(policy).to receive(:permanent_train_options)
        .with(game, corporation)
        .and_return([{ name: 'D', price: 700 }])

      step = Object.new
      step.define_singleton_method(:choices_ability) { |_candidate| { 'sp_on' => 'Activate' } }

      expect(policy.send(:share_premium_decision, game, step, company)).to be_nil
    end

    it 'values concession private access by corporation size' do
      two_share = game.corporation_by_id('IR')
      five_share = game.corporation_by_id('G&CU')
      ten_share = game.corporation_by_id('WAB')

      best_a_for_five = policy.send(:best_available_private_value, game, player, five_share, :A)
      best_a_for_two = policy.send(:best_available_private_value, game, player, two_share, :A)
      best_b_for_two = policy.send(:best_available_private_value, game, player, two_share, :B)

      expect(policy.send(:concession_private_value_score, game, player, ten_share))
        .to eq(policy.send(:attached_private_value, game, ten_share))
      expect(policy.send(:concession_private_value_score, game, player, five_share)).to eq(best_a_for_five)
      expect(policy.send(:concession_private_value_score, game, player, two_share)).to eq(best_a_for_two + best_b_for_two)
    end

    it 'considers another corporation abandoned token as a token replacement slot' do
      corporation = game.corporation_by_id('WAB')
      closed_corporation = game.corporation_by_id('CBQ')
      token = Engine::Token.new(closed_corporation)
      token.status = :flipped
      city = Struct.new(:tokens).new([token])

      expect(policy.send(:abandoned_token_slot, corporation, city)).to eq(0)
    end

    it 'does not replace an abandoned token where it already has a live token' do
      corporation = game.corporation_by_id('WAB')
      closed_corporation = game.corporation_by_id('CBQ')
      own_token = Engine::Token.new(corporation)
      abandoned_token = Engine::Token.new(closed_corporation)
      abandoned_token.status = :flipped
      city = Struct.new(:tokens).new([own_token, abandoned_token])

      expect(policy.send(:abandoned_token_slot, corporation, city)).to be_nil
    end

    it 'penalizes Peoria approaches that cannot connect to the P2 upgrade' do
      bad_tile = game.tile_by_id('9-0').dup.rotate!(2)
      good_tile = game.tile_by_id('9-0').dup.rotate!(1)

      expect(policy.send(:city_upgrade_stranded_approach_penalty, game.hex_by_id('D7'), bad_tile))
        .to eq(described_class::CITY_UPGRADE_STRANDED_APPROACH_PENALTY)
      expect(policy.send(:city_upgrade_stranded_approach_penalty, game.hex_by_id('D9'), good_tile)).to eq(0)
    end

    it 'uses sampled routes as a fallback when isolated exact routing finds nothing' do
      corporation = game.corporation_by_id('WAB')
      train = Struct.new(:id, :name, :rusts_on, :obsolete_on)
      trains = [train.new('2-0', '2', '4', nil), train.new('3-1', '3', '4+2C', nil)]
      sampled_routes = [Struct.new(:train).new(trains.last)]
      finder = instance_double(Game::G18IL::Bot::RouteFinder)

      allow(Game::G18IL::Bot::RouteFinder).to receive(:new).with(game).and_return(finder)
      allow(policy).to receive(:valid_cached_routes).with(game, corporation, trains).and_return(nil)
      allow(policy).to receive(:sampled_route_combination).with(game, corporation, trains, finder).and_return(sampled_routes)
      allow(finder).to receive(:isolated_maximum_routes).and_return(nil)
      allow(policy).to receive(:prefer_cached_routes).with(game, corporation, trains, sampled_routes).and_return(sampled_routes)

      expect(policy.send(:best_route_combination, game, corporation, trains)).to eq(sampled_routes)
    end

    it 'uses long exact-route limits for a single permanent long train' do
      corporation = game.corporation_by_id('WAB')
      train = Struct.new(:id, :name, :rusts_on, :obsolete_on).new('4+2C-1', '4+2C', nil, nil)
      sampled_routes = [Struct.new(:train).new(train)]
      finder = instance_double(Game::G18IL::Bot::RouteFinder)

      allow(Game::G18IL::Bot::RouteFinder).to receive(:new).with(game).and_return(finder)
      allow(policy).to receive(:valid_cached_routes).with(game, corporation, [train]).and_return(nil)
      allow(policy).to receive(:sampled_route_combination).with(game, corporation, [train], finder).and_return(sampled_routes)
      allow(finder).to receive(:isolated_maximum_routes).and_return(nil)
      allow(policy).to receive(:prefer_cached_routes)
        .with(game, corporation, [train], sampled_routes)
        .and_return(sampled_routes)

      expect(finder).to receive(:isolated_maximum_routes).with(
        corporation,
        trains: [train],
        path_timeout: described_class::ISOLATED_LONG_ROUTE_PATH_TIMEOUT,
        route_timeout: described_class::ISOLATED_LONG_ROUTE_COMBINATION_TIMEOUT,
        route_limit: described_class::ISOLATED_LONG_ROUTE_LIMIT,
        wall_timeout: described_class::ISOLATED_LONG_ROUTE_WALL_TIMEOUT,
      ).and_return(nil)
      expect(policy.send(:best_route_combination, game, corporation, [train])).to eq(sampled_routes)
    end

    it 'keeps ordinary 2- and 3-trains on the sampled route path by default' do
      train = Struct.new(:name, :distance)

      expect(policy.send(:isolated_exact_routes_for_trains?, [train.new('2', 2)])).to be false
      expect(policy.send(:isolated_exact_routes_for_trains?, [train.new('3', 3)])).to be false
    end

    it 'can exact-route every train set when configured' do
      train = Struct.new(:distance).new(2)

      with_exact_route_mode('all') do
        expect(policy.send(:isolated_exact_routes_for_trains?, [train])).to be true
      end
    end

    it 'exact-routes 4-trains, 0+3C, Pullman, and route-extension trains by default' do
      train = Struct.new(:name, :distance)
      distance = [
        { 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
        { 'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4 },
      ]

      %w[4 0+3C 1+3C 4+2C 5+1C 5+2C 6 6+1C 9].each do |name|
        expect(policy.send(:isolated_exact_routes_for_trains?, [train.new(name, distance)]))
          .to be true
      end
    end

    it 'can disable isolated exact routing' do
      train = Struct.new(:distance).new([
                                          { 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                                          { 'nodes' => %w[city offboard], 'pay' => 5, 'visit' => 5 },
                                        ])

      with_exact_route_mode('0') do
        expect(policy.send(:isolated_exact_routes_for_trains?, [train])).to be false
      end
    end

    it 'can restrict isolated exact routing to long trains' do
      short = Struct.new(:name, :distance).new('2', 2)
      long = Struct.new(:name, :distance).new('5', 5)

      with_exact_route_mode('long') do
        expect(policy.send(:isolated_exact_routes_for_trains?, [short])).to be false
        expect(policy.send(:isolated_exact_routes_for_trains?, [long])).to be true
      end
    end

    it 'does not start surplus concession auctions without an opening plan' do
      owned = game.company_by_id('IR')
      candidate = game.company_by_id('RI')
      owned.owner = player
      player.companies << owned

      allow(policy).to receive(:second_concession_plan_value).with(game, player, candidate, bid_price: 0).and_return(0)

      expect(policy.send(:auction_startable?, game, player, candidate)).to be false
    end

    it 'can start a first concession auction when the opening plan merely ties the alternatives' do
      candidate = game.company_by_id('IR')
      step = Object.new
      step.define_singleton_method(:min_bid) { |_company| 10 }

      allow(policy).to receive(:available_concession_alternatives).with(game, player, step, candidate).and_return([candidate])
      allow(policy).to receive(:best_concession_opening_plan)
        .with(game, player, [candidate], required: [candidate], available_cash: player.cash - 10)
        .and_return([candidate])
      allow(policy).to receive(:best_concession_opening_plan_score)
        .with(game, player, [candidate], excluded: [candidate])
        .and_return(100)
      allow(policy).to receive(:concession_opening_plan_score).with(game, player, [candidate]).and_return(100)

      expect(policy.send(:concession_auction_plan, game, player, candidate, step)).to eq([candidate])
      expect(policy.send(:concession_auction_value, game, player, candidate, 80, step)).to be >= 10
    end

    it 'prices a useful first concession from its launch plan instead of the minimum bid' do
      candidate = game.company_by_id('IR')
      step = Object.new
      companies = game.companies
      step.define_singleton_method(:companies) { companies }
      step.define_singleton_method(:min_bid) { |_company| 10 }

      value = policy.send(:auction_value, game, player, candidate, step: step)

      expect(value).to be > described_class::CONCESSION_MIN_PLAN_BID
      expect(value).to be <= described_class::EARLY_CONCESSION_BID_CAP
    end

    it 'normalizes first-concession bids against the best available opening score' do
      concessions = %w[IR NC G&CU RI CBQ V WAB C&EI].map { |id| game.company_by_id(id) }
      step = Object.new
      step.define_singleton_method(:companies) { concessions }
      step.define_singleton_method(:min_bid) { |_company| 10 }

      values = concessions.to_h do |company|
        [company.sym, policy.send(:auction_value, game, player, company, step: step)]
      end

      expect(values.values.max).to eq(described_class::FIRST_CONCESSION_TOP_BID)
      expect(values.values.max).to eq(described_class::EARLY_CONCESSION_BID_CAP)
      expect(values.fetch('NC')).to eq(described_class::FIRST_CONCESSION_TOP_BID)
      expect(values.fetch('IR')).to be < described_class::FIRST_CONCESSION_TOP_BID
      expect(values.fetch('G&CU')).to be < values.fetch('IR')
      expect(values.fetch('WAB')).to be < values.fetch('C&EI')
    end

    it 'keeps first-concession bids anchored after a stronger concession sells' do
      nc = game.company_by_id('NC')
      c_ei = game.company_by_id('C&EI')
      game.players[1].companies << nc
      nc.owner = game.players[1]
      step = Object.new
      step.define_singleton_method(:companies) { [c_ei] }
      step.define_singleton_method(:min_bid) { |_company| 10 }

      value = policy.send(:auction_value, game, player, c_ei, step: step)

      expect(value).to be < described_class::FIRST_CONCESSION_TOP_BID
      expect(value).to be >= described_class::CONCESSION_MIN_PLAN_BID
    end

    it 'leaves one five-player opening investor when stronger presidency packages are already claimed' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      %w[NC IR G&CU C&EI].zip(five_player_game.players.first(4)).each do |id, owner|
        concession = five_player_game.company_by_id(id)
        concession.owner = owner
        owner.companies << concession
      end
      allow(five_player_policy).to receive(:concession_opening_corporation_score) do |_game, _player, company|
        company.owner&.player? ? 200 : 100
      end

      expect(five_player_policy.send(:presidency_free_investor_mode?, five_player_game, investor)).to be true
      expect(five_player_policy.send(:opening_investor_preferred?, five_player_game, investor)).to be true
      expect(
        five_player_policy.send(
          :concession_auction_startable?,
          five_player_game,
          investor,
          five_player_game.company_by_id('WAB'),
        ),
      ).to be false
    end

    it 'still takes an exceptional remaining concession instead of forcing the five-player investor role' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      %w[NC IR G&CU C&EI].zip(five_player_game.players.first(4)).each do |id, owner|
        concession = five_player_game.company_by_id(id)
        concession.owner = owner
        owner.companies << concession
      end
      allow(five_player_policy).to receive(:concession_opening_corporation_score) do |_game, _player, company|
        company.sym == 'WAB' ? 300 : 200
      end

      expect(five_player_policy.send(:opening_investor_preferred?, five_player_game, investor)).to be false
    end

    it 'caps an expensive first concession bid when the stronger opening defense would not fit' do
      player.set_cash(240, game.bank)
      c_ei = game.company_by_id('C&EI')
      concessions = %w[IR NC C&EI].map { |id| game.company_by_id(id) }
      step = Object.new
      step.define_singleton_method(:companies) { concessions }
      step.define_singleton_method(:min_bid) { |_company| 10 }

      allow(policy).to receive(:launch_can_fund_train?).and_return(true)

      value = policy.send(:concession_auction_value, game, player, c_ei, 300, step)

      expect(value).to eq(40)
    end

    it 'remembers an expensive first concession as needing stronger takeover defense' do
      c_ei = game.company_by_id('C&EI')
      expensive_bid = described_class::EXPENSIVE_FIRST_CONCESSION_DEFENSE_BID
      step = Object.new
      step.define_singleton_method(:companies) { [c_ei] }
      step.define_singleton_method(:min_bid) { |_company| expensive_bid }

      allow(policy).to receive(:launch_can_fund_train?).and_return(true)

      policy.send(:remember_concession_launch_intent, game, player, c_ei, step)

      intent = policy.instance_variable_get(:@concession_launch_intents).fetch(player.id)
      expect(intent[:defense]).to eq(:expensive_first_concession)
    end

    it 'reserves protected launch cash when valuing a concession auction bid' do
      candidate = game.company_by_id('WAB')
      step = Object.new

      allow(policy).to receive(:auction_item_value).with(game, player, candidate).and_return(300)
      allow(policy).to receive(:concession_auction_value).with(game, player, candidate, 300, step).and_return(300)
      allow(policy).to receive(:concession_bid_cap).with(game, candidate).and_return(300)
      allow(policy).to receive(:concession_opening_cost).with(game, player, candidate).and_return(160)
      allow(policy).to receive(:minimum_concession_launch_cash_required)
        .with(game, player, candidate, available_cash: player.cash)
        .and_return(240)

      expect(policy.send(:auction_value, game, player, candidate, step: step)).to eq(120)
    end

    it 'keeps normalized first-concession values under the hard cap across player counts' do
      value_for_players = lambda do |count|
        scaled_game = Game::G18IL::Game.new(Array.new(count) { |index| "P#{index}" })
        scaled_policy = described_class.new
        scaled_step = Object.new
        scaled_companies = scaled_game.companies
        scaled_step.define_singleton_method(:companies) { scaled_companies }
        scaled_step.define_singleton_method(:min_bid) { |_company| 10 }

        scaled_policy.send(
          :auction_value,
          scaled_game,
          scaled_game.players.first,
          scaled_game.company_by_id('IR'),
          step: scaled_step,
        )
      end

      expect(value_for_players.call(2)).to be <= described_class::FIRST_CONCESSION_TOP_BID
      expect(value_for_players.call(4)).to be <= described_class::FIRST_CONCESSION_TOP_BID
      expect(value_for_players.call(6)).to be <= described_class::FIRST_CONCESSION_TOP_BID
    end

    it 'can start a second concession auction in two-player openings when the plan works' do
      two_player_game = Game::G18IL::Game.new(%w[A B])
      two_player_policy = described_class.new
      two_player = two_player_game.players.first
      owned = two_player_game.company_by_id('IR')
      candidate = two_player_game.company_by_id('RI')
      owned.owner = two_player
      two_player.companies << owned
      step = Object.new
      step.define_singleton_method(:min_bid) { |_company| 10 }

      allow(two_player_policy)
        .to receive(:second_concession_plan_value)
        .with(two_player_game, two_player, candidate, bid_price: 10)
        .and_return(100)

      expect(two_player_policy.send(:auction_startable?, two_player_game, two_player, candidate, step: step)).to be true
    end

    it 'can start a second concession auction before opening when the two-corporation plan works' do
      owned = game.company_by_id('IR')
      candidate = game.company_by_id('RI')
      owned.owner = player
      player.companies << owned
      step = Object.new
      step.define_singleton_method(:min_bid) { |_company| 10 }

      allow(policy).to receive(:second_concession_plan_value).with(game, player, candidate, bid_price: 10).and_return(100)

      expect(policy.send(:auction_startable?, game, player, candidate, step: step)).to be true
    end

    it 'does not treat two-player second concessions as saturated' do
      two_player_game = Game::G18IL::Game.new(%w[A B])
      two_player_policy = described_class.new
      two_player = two_player_game.players.first
      owned = two_player_game.company_by_id('IR')
      candidate = two_player_game.company_by_id('NC')
      owned.owner = two_player
      two_player.companies << owned

      expect(two_player_policy.send(:second_concession_saturated?, two_player_game, two_player)).to be false
      expect(two_player_policy.send(:auction_startable?, two_player_game, two_player, candidate)).to be true
    end

    it 'prices a second concession from marginal plan value' do
      owned = game.company_by_id('IR')
      candidate = game.company_by_id('RI')
      owned.owner = player
      player.companies << owned
      step = Object.new
      step.define_singleton_method(:min_bid) { |_company| 10 }

      allow(policy).to receive(:available_concession_alternatives)
        .with(game, player, step, candidate)
        .and_return([candidate])
      allow(policy).to receive(:best_concession_opening_plan)
        .with(game, player, [candidate], required: [candidate], available_cash: player.cash - 10)
        .and_return([owned, candidate])
      allow(policy).to receive(:concession_opening_plan_score)
        .with(game, player, [owned, candidate])
        .and_return(180)
      allow(policy).to receive(:best_concession_opening_plan_score)
        .with(game, player, [candidate], excluded: [candidate])
        .and_return(100)

      expect(policy.send(:concession_auction_value, game, player, candidate, 100, step)).to eq(55)
    end

    it 'does not start a second concession auction when two-corporation openings are saturated' do
      current_owned = game.company_by_id('IR')
      candidate = game.company_by_id('NC')
      current_owned.owner = player
      player.companies << current_owned

      game.players[1].companies.concat([game.company_by_id('WAB'), game.company_by_id('C&EI')])
      game.players[2].companies.concat([game.company_by_id('G&CU'), game.company_by_id('RI')])
      game.players[1].companies.each { |company| company.owner = game.players[1] }
      game.players[2].companies.each { |company| company.owner = game.players[2] }

      allow(policy).to receive(:second_corporation_bailout_motive?).with(game, player).and_return(false)

      expect(policy.send(:auction_startable?, game, player, candidate)).to be false
    end

    it 'follows a remembered concession opening plan in the stock round' do
      ir = game.company_by_id('IR')
      ri = game.company_by_id('RI')
      ir.owner = player
      ri.owner = player
      player.companies.concat([ir, ri])
      policy.instance_variable_set(
        :@concession_launch_intents,
        player.id => { turn: game.turn, corporations: %w[RI IR] },
      )
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }

      allow(policy).to receive(:launch_can_fund_train?).and_return(true)

      decision = policy.send(:stock_decision, game, step, player, %w[par])

      expect(decision.action.corporation).to eq(game.corporation_by_id('RI'))
    end

    it 'continues a remembered concession opening plan before capitalizing an already-open presidency' do
      c_ei = game.company_by_id('C&EI')
      ri = game.company_by_id('RI')
      c_ei.owner = player
      ri.owner = player
      player.companies.concat([c_ei, ri])

      open_corporation = game.corporation_by_id('C&EI')
      open_corporation.owner = player
      open_corporation.ipoed = true
      game.stock_market.set_par(open_corporation, game.par_prices.find { |price| price.price == 80 })
      policy.instance_variable_set(
        :@concession_launch_intents,
        player.id => { turn: game.turn, corporations: %w[C&EI RI] },
      )
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }

      allow(policy).to receive(:launch_can_fund_train?).and_return(true)

      decision = policy.send(:concession_launch_intent_stock_decision, game, step, player, %w[par buy_shares])

      expect(decision.action).to be_a(Engine::Action::Par)
      expect(decision.action.corporation).to eq(game.corporation_by_id('RI'))
    end

    it 'orders a two-concession plan so both openings remain fundable' do
      nc = game.company_by_id('NC')
      c_ei = game.company_by_id('C&EI')

      plan = policy.send(:executable_concession_opening_plan, game, player, [c_ei, nc], available_cash: 330)

      expect(plan.map(&:id)).to contain_exactly('NC', 'C&EI')
    end

    it 'starts an owned concession plan at a low enough par to preserve the next launch' do
      nc = game.company_by_id('NC')
      c_ei = game.company_by_id('C&EI')
      [nc, c_ei].each do |company|
        company.owner = player
        player.companies << company
      end
      player.set_cash(330, game.bank)
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }

      decision = policy.send(:stock_decision, game, step, player, %w[par])

      expect(decision.action).to be_a(Engine::Action::Par)
      expect(decision.action.corporation).to eq(game.corporation_by_id('NC'))
      expect(decision.action.share_price.price).to eq(40)
    end

    it 'does not let a strategic launch bypass an affordable IR and NC opening plan' do
      ir = game.company_by_id('IR')
      nc = game.company_by_id('NC')
      [ir, nc].each do |company|
        company.owner = player
        player.companies << company
      end
      player.set_cash(240, game.bank)
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }

      strategic = policy.send(:strategic_stock_decision, game, step, player, %w[par])
      decision = policy.send(:stock_decision, game, step, player, %w[par])

      expect(strategic).to be_nil
      expect(decision.action.corporation).to eq(game.corporation_by_id('IR'))
      expect(decision.action.share_price.price).to eq(80)
    end

    it 'starts a remembered concession plan at a low enough par to preserve the next launch' do
      nc = game.company_by_id('NC')
      c_ei = game.company_by_id('C&EI')
      [nc, c_ei].each do |company|
        company.owner = player
        player.companies << company
      end
      player.set_cash(330, game.bank)
      policy.instance_variable_set(
        :@concession_launch_intents,
        player.id => { turn: game.turn, corporations: %w[NC C&EI], defense: :normal },
      )
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }

      decision = policy.send(:concession_launch_intent_stock_decision, game, step, player, %w[par])

      expect(decision.action).to be_a(Engine::Action::Par)
      expect(decision.action.corporation).to eq(game.corporation_by_id('NC'))
      expect(decision.action.share_price.price).to eq(40)
    end

    it 'keeps only a small price-enforcement value for surplus concessions without a plan' do
      owned = game.company_by_id('IR')
      candidate = game.company_by_id('RI')
      owned.owner = player
      player.companies << owned

      allow(policy).to receive(:second_concession_plan_value).with(game, player, candidate).and_return(0)

      expect(policy.send(:auction_item_value, game, player, candidate))
        .to eq(described_class::CONCESSION_PRICE_ENFORCEMENT_VALUE)
    end

    it 'does not open concession auctions only to price enforce' do
      candidate = game.company_by_id('RI')
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::SelectionAuction }
      step.define_singleton_method(:choice_available?) { |_entity| false }
      step.define_singleton_method(:auctioning) { nil }
      step.define_singleton_method(:companies) { [candidate] }
      step.define_singleton_method(:may_bid?) { |_company| true }
      step.define_singleton_method(:min_bid) { |_company| 0 }

      allow(policy).to receive(:auction_startable?).with(game, player, candidate, step: step).and_return(true)
      allow(policy).to receive(:concession_auction_plan).with(game, player, candidate, step).and_return(nil)
      allow(policy).to receive(:auction_value).with(game, player, candidate, step: step)
        .and_return(described_class::CONCESSION_PRICE_ENFORCEMENT_VALUE)

      expect(policy.send(:auction_decision, game, step, player, %w[bid])).to be_nil
    end

    it 'values the premium NC and IR home tokens when comparing concessions' do
      ir = game.company_by_id('IR')
      nc = game.company_by_id('NC')
      ri = game.company_by_id('RI')

      expect(policy.send(:concession_value, game, player, ir))
        .to be > policy.send(:concession_value, game, player, ri)
      expect(policy.send(:concession_value, game, player, nc))
        .to be > policy.send(:concession_value, game, player, ri)
    end

    it 'rewards a two-share corporation paired with a larger train-bank corporation' do
      nc = game.corporation_by_id('NC')
      wab = game.corporation_by_id('WAB')
      cbq = game.corporation_by_id('CBQ')

      expect(policy.send(:two_corporation_train_bank_pair_synergy, [nc, wab]))
        .to eq(described_class::TWO_CORPORATION_TRAIN_BANK_PAIR_BONUS)
      expect(policy.send(:two_corporation_train_bank_pair_synergy, [wab, cbq])).to eq(0)
    end

    it 'reserves cash to launch the low-capital half of a train-bank pair' do
      nc_concession = game.company_by_id('NC')
      nc = game.corporation_by_id('NC')
      wab = game.corporation_by_id('WAB')
      nc_concession.owner = player
      player.companies << nc_concession
      wab.owner = player
      wab.ipoed = true
      target = { corporation: nc, required_cash: 80 }
      step = Object.new

      allow(policy).to receive(:strategic_concession_launch_target).with(game, step, player).and_return(target)
      allow(policy).to receive(:president_capitalization_share_available?).with(game, step, player).and_return(true)
      allow(policy).to receive(:concession_launch_reachable_this_stock_round?).with(game, step, player, target).and_return(true)

      expect(policy.send(:concession_launch_cash_reserve, game, step, player)).to eq(80)
    end

    it 'rewards dividends that keep a low-capital corporation behind its train-bank sibling' do
      nc = game.corporation_by_id('NC')
      wab = game.corporation_by_id('WAB')
      nc.owner = player
      wab.owner = player
      nc.ipoed = true
      wab.ipoed = true
      game.stock_market.set_par(nc, game.par_prices.find { |price| price.price == 60 })
      game.stock_market.set_par(wab, game.par_prices.find { |price| price.price == 60 })
      game.buy_train(wab, game.depot.min_depot_train, :free)
      game.buy_train(wab, game.depot.min_depot_train, :free)
      option = {}

      allow(policy).to receive(:dividend_resulting_share_price).with(game, nc, option)
        .and_return(Struct.new(:price).new(60))

      expect(policy.send(:early_sibling_train_transfer_order_bonus, game, nc, option))
        .to eq(described_class::EARLY_SIBLING_TRAIN_TRANSFER_ORDER_BONUS)

      allow(policy).to receive(:dividend_resulting_share_price).with(game, nc, option)
        .and_return(Struct.new(:price).new(80))

      expect(policy.send(:early_sibling_train_transfer_order_bonus, game, nc, option)).to eq(0)
    end

    it 'prefers a par that leaves cash for an extra president share over a higher unaffordable par' do
      player.set_cash(280, game.bank)
      corporation = game.corporation_by_id('CBQ')
      price_80 = Struct.new(:price).new(80)
      price_100 = Struct.new(:price).new(100)

      score_80 = policy.send(:launch_par_score, game, player, corporation, price_80)
      score_100 = policy.send(:launch_par_score, game, player, corporation, price_100)

      expect(score_80 <=> score_100).to eq(1)
    end

    it 'prefers the par that maximizes useful starting treasury for a five-share corporation' do
      player.set_cash(290, game.bank)
      corporation = game.corporation_by_id('G&CU')
      price_40 = Struct.new(:price).new(40)
      price_60 = Struct.new(:price).new(60)
      price_80 = Struct.new(:price).new(80)
      price_100 = Struct.new(:price).new(100)

      score_40 = policy.send(:launch_par_score, game, player, corporation, price_40)
      score_60 = policy.send(:launch_par_score, game, player, corporation, price_60)
      score_80 = policy.send(:launch_par_score, game, player, corporation, price_80)
      score_100 = policy.send(:launch_par_score, game, player, corporation, price_100)

      expect(score_80 <=> score_100).to eq(1)
      expect(score_80 <=> score_60).to eq(1)
      expect(score_80 <=> score_40).to eq(1)
      expect(policy.send(:launch_projected_treasury, game, player, corporation, 80)).to be >
        policy.send(:launch_projected_treasury, game, player, corporation, 100)
    end

    it 'keeps the higher par when two par prices leave the same extra share buying room' do
      player.set_cash(280, game.bank)
      corporation = game.corporation_by_id('CBQ')
      price_60 = Struct.new(:price).new(60)
      price_80 = Struct.new(:price).new(80)

      score_60 = policy.send(:launch_par_score, game, player, corporation, price_60)
      score_80 = policy.send(:launch_par_score, game, player, corporation, price_80)

      expect(score_80 <=> score_60).to eq(1)
    end

    it 'chooses a defendable launch par over a higher vulnerable par' do
      launch_policy = described_class.new(
        profile: Game::G18IL::Bot::PolicyProfile.new(par_values: { 60 => 0, 80 => 500 }),
      )
      player.set_cash(220, game.bank)
      corporation = game.corporation_by_id('C&EI')
      step = Object.new
      prices = [Struct.new(:price).new(60), Struct.new(:price).new(80)]
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| prices }

      allow(launch_policy).to receive(:launch_can_fund_train?).and_return(true)

      share_price = launch_policy.send(:launch_share_price, game, step, player, corporation, preserve_intent: false)

      expect(share_price.price).to eq(60)
    end

    it 'uses a stronger launch par defense after an expensive first concession win' do
      launch_policy = described_class.new(
        profile: Game::G18IL::Bot::PolicyProfile.new(par_values: { 40 => 0, 60 => 500, 80 => 600 }),
      )
      player.set_cash(220, game.bank)
      corporation = game.corporation_by_id('C&EI')
      step = Object.new
      prices = [Struct.new(:price).new(40), Struct.new(:price).new(60), Struct.new(:price).new(80)]
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| prices }
      launch_policy.instance_variable_set(
        :@concession_launch_intents,
        player.id => { turn: game.turn, corporations: ['C&EI'], defense: :expensive_first_concession },
      )

      allow(launch_policy).to receive(:launch_can_fund_train?).and_return(true)

      share_price = launch_policy.send(:launch_share_price, game, step, player, corporation, preserve_intent: true)

      expect(share_price.price).to eq(40)
    end

    it 'does not open an undefended second corporation' do
      existing = game.corporation_by_id('CBQ')
      target = game.corporation_by_id('C&EI')
      concession = game.company_by_id('C&EI')
      existing.owner = player
      existing.ipoed = true
      concession.owner = player
      player.companies << concession
      player.set_cash(120, game.bank)
      game.stock_market.set_par(existing, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      prices = [Struct.new(:price).new(40), Struct.new(:price).new(80)]
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| prices }

      allow(policy).to receive(:launch_can_fund_train?).and_return(true)

      expect(policy.send(:launch_share_price, game, step, player, target, preserve_intent: false)).to be_nil
    end

    it 'penalizes a ten-share launch par that leaves the presidency easy to steal' do
      takeover_policy = described_class.new(
        profile: Game::G18IL::Bot::PolicyProfile.new(closure_strategy_weight: 0),
      )
      player.set_cash(160, game.bank)
      corporation = game.corporation_by_id('C&EI')
      price_40 = Struct.new(:price).new(40)
      price_80 = Struct.new(:price).new(80)

      score_40 = takeover_policy.send(:launch_par_score, game, player, corporation, price_40)
      score_80 = takeover_policy.send(:launch_par_score, game, player, corporation, price_80)

      expect(takeover_policy.send(:launch_takeover_safety_score, game, player, corporation, 40)).to be_positive
      expect(takeover_policy.send(:launch_takeover_safety_score, game, player, corporation, 80)).to be_negative
      expect(score_40 <=> score_80).to eq(1)
    end

    it 'preserves a two-concession launch plan only when the current par leaves takeover protection cash' do
      nc = game.company_by_id('NC')
      c_ei = game.company_by_id('C&EI')
      [nc, c_ei].each do |company|
        company.owner = player
        player.companies << company
      end
      player.set_cash(330, game.bank)
      policy.instance_variable_set(
        :@concession_launch_intents,
        player.id => { turn: game.turn, corporations: %w[NC C&EI] },
      )
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }
      corporation = game.corporation_by_id('NC')

      expect(policy.send(:concession_intent_par_preserves_follow_through?, game, step, player, corporation, 40))
        .to be true
      expect(policy.send(:concession_intent_par_preserves_follow_through?, game, step, player, corporation, 80))
        .to be false
    end

    it 'does not require protected launch cash when rivals cannot afford a takeover' do
      corporation = game.corporation_by_id('C&EI')
      game.players.reject { |candidate| candidate == player }.each { |candidate| candidate.set_cash(0, game.bank) }

      expect(
        policy.send(:launch_cash_required_for_position, game, player, corporation, 100, protect_presidency: true),
      ).to eq(200)
    end

    it 'requires protected launch cash when a rival can still afford a takeover' do
      corporation = game.corporation_by_id('C&EI')
      game.players[1].set_cash(300, game.bank)

      expect(
        policy.send(:launch_cash_required_for_position, game, player, corporation, 100, protect_presidency: true),
      ).to eq(300)
    end

    it 'allows the first high par in a two-concession plan when rivals have spent their takeover cash' do
      c_ei = game.company_by_id('C&EI')
      wab = game.company_by_id('WAB')
      [c_ei, wab].each do |company|
        company.owner = player
        player.companies << company
      end
      player.set_cash(400, game.bank)
      game.players.reject { |candidate| candidate == player }.each { |candidate| candidate.set_cash(0, game.bank) }
      policy.instance_variable_set(
        :@concession_launch_intents,
        player.id => { turn: game.turn, corporations: %w[C&EI WAB] },
      )
      step = Object.new
      par_prices = game.par_prices
      step.define_singleton_method(:get_par_prices) { |_entity, _corporation| par_prices }
      corporation = game.corporation_by_id('C&EI')

      expect(policy.send(:concession_intent_par_preserves_follow_through?, game, step, player, corporation, 100))
        .to be true

      game.players[1].set_cash(300, game.bank)

      expect(policy.send(:concession_intent_par_preserves_follow_through?, game, step, player, corporation, 100))
        .to be false
    end

    it 'requires protected cash for an ordinary strategic concession launch' do
      corporation = game.corporation_by_id('C&EI')

      expect(policy.send(:concession_launch_cash_required, game, player, corporation, 80)).to eq(240)
    end

    it 'does not buy a lockdown share before a rival draws level' do
      corporation = game.corporation_by_id('C&EI')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      player.set_cash(80, game.bank)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      share = corporation.shares.reject(&:president).first
      share.buyable = true
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:can_buy?) { |_entity, _bundle| true }

      decision = policy.send(:presidency_lockdown_purchase_decision, game, step, player, %w[buy_shares par])

      expect(decision).to be_nil
    end

    it 'buys a lockdown share when a rival draws level with the president' do
      corporation = game.corporation_by_id('C&EI')
      rival = game.players[1]
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      player.set_cash(80, game.bank)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      shares = corporation.shares.reject(&:president)
      shares.first(2).each { |share| game.share_pool.transfer_shares(ShareBundle.new(share), rival) }
      shares[2].buyable = true
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:can_buy?) { |_entity, _bundle| true }

      decision = policy.send(:presidency_lockdown_purchase_decision, game, step, player, %w[buy_shares par])

      expect(decision.action).to be_a(Engine::Action::BuyShares)
      expect(decision.action.bundle.corporation).to eq(corporation)
      expect(decision.reason).to include('harder to take over')
    end

    it 'buys a post-conversion retention share when a rival holding makes the presidency shallow' do
      corporation = game.corporation_by_id('C&EI')
      rival = game.players[1]
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      player.set_cash(100, game.bank)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      shares = corporation.shares.reject(&:president)
      game.share_pool.transfer_shares(ShareBundle.new(shares[1]), rival)
      game.share_pool.transfer_shares(ShareBundle.new(shares[0]), rival)
      shares[2].buyable = true
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::PostConversionShares }
      step.define_singleton_method(:corporation) { corporation }
      step.define_singleton_method(:can_buy?) { |_entity, _bundle| true }

      decision = policy.send(:presidency_lockdown_purchase_decision, game, step, player, %w[buy_shares pass])

      expect(decision.action).to be_a(Engine::Action::BuyShares)
      expect(decision.action.bundle.corporation).to eq(corporation)
      expect(decision.reason).to include('harder to take over')
    end

    it 'treats post-formation IC as a presidency worth protecting even before it is dominant' do
      ic = game.ic
      ic.ipoed = true
      game.stock_market.set_par(ic, game.par_prices.find { |price| price.price == 80 })

      allow(game).to receive(:post_ic_formation_stock_round?).and_return(true)
      allow(policy).to receive(:weak_stock_corporation?).with(game, ic).and_return(true)
      allow(policy).to receive(:ic_engine_dominant?).with(game).and_return(false)

      expect(policy.send(:presidency_worth_protecting?, game, ic)).to be true
    end

    it 'prioritizes an IC share that locks down the current IC presidency' do
      ic = game.ic
      ic.ipoed = true
      game.stock_market.set_par(ic, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(ic.presidents_share), player)
      bundle = Struct.new(:corporation, :percent, :price, :owner).new(ic, 10, 80, game.share_pool)

      allow(game).to receive(:post_ic_formation_stock_round?).and_return(true)
      allow(policy).to receive(:ic_engine_dominant?).with(game).and_return(false)

      expect(policy.send(:ic_presidency_priority, game, player, bundle))
        .to eq(described_class::IC_PRESIDENCY_DEFENSE_PRIORITY)
    end

    it 'prioritizes buying an IC share that can take over the IC presidency' do
      ic = game.ic
      rival = game.players[1]
      ic.ipoed = true
      game.stock_market.set_par(ic, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(ic.presidents_share), rival)
      player_shares = ic.shares.reject(&:president).first(2)
      player_shares.each { |share| game.share_pool.transfer_shares(ShareBundle.new(share), player) }
      bundle = Struct.new(:corporation, :percent, :price, :owner).new(ic, 10, 80, game.share_pool)

      allow(game).to receive(:post_ic_formation_stock_round?).and_return(true)
      allow(policy).to receive(:ic_engine_dominant?).with(game).and_return(false)

      expect(policy.send(:ic_presidency_priority, game, player, bundle))
        .to eq(described_class::IC_PRESIDENCY_PURSUIT_PRIORITY)
    end

    it 'buys an IC share out of a controlled corporation' do
      ic = game.ic
      corporation = game.corporation_by_id('C&EI')
      ic.ipoed = true
      corporation.owner = player
      corporation.ipoed = true
      player.set_cash(100, game.bank)
      game.stock_market.set_par(ic, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(ic.shares.reject(&:president).first), corporation)
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:can_buy?) { |_entity, _bundle| true }

      decision = policy.send(:ic_share_purchase_decision, game, step, player, %w[buy_shares pass])

      expect(decision.action).to be_a(Engine::Action::BuyShares)
      expect(decision.action.bundle.corporation).to eq(ic)
      expect(decision.action.bundle.owner).to eq(corporation)
    end

    it 'allows a strategic same-president train transfer after the seller has operated' do
      buyer = game.corporation_by_id('CBQ')
      seller = game.corporation_by_id('G&CU')
      buyer.owner = player
      seller.owner = player
      buyer.set_cash(400, game.bank)
      seller.set_cash(400, game.bank)
      game.stock_market.set_par(buyer, game.par_prices.find { |price| price.price == 80 })
      game.stock_market.set_par(seller, game.par_prices.find { |price| price.price == 100 })
      train = Struct.new(:owner, :price, :rusts_on, :obsolete_on) do
        def owned_by_corporation?
          true
        end
      end.new(seller, 400, nil, nil)

      allow(game).to receive(:operated_this_round?).with(seller).and_return(true)
      allow(policy).to receive(:strategic_train_transfer_target_price).with(game).and_return(740)

      expect(policy.send(:bot_may_buy_train?, game, buyer, train)).to be true
    end

    it 'allows a same-president permanent transfer to replace a rusting train' do
      buyer = game.corporation_by_id('G&CU')
      seller = game.corporation_by_id('WAB')
      buyer.owner = player
      seller.owner = player
      buyer.set_cash(700, game.bank)
      seller.set_cash(100, game.bank)
      buyer.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('4', 'D', nil)
      game.stock_market.set_par(buyer, game.par_prices.find { |price| price.price == 80 })
      game.stock_market.set_par(seller, game.par_prices.find { |price| price.price == 100 })
      train = Struct.new(:owner, :price, :rusts_on, :obsolete_on) do
        def owned_by_corporation?
          true
        end
      end.new(seller, 700, nil, nil)

      allow(game).to receive(:operated_this_round?).with(seller).and_return(true)
      allow(policy).to receive(:strategic_train_transfer_target_price).with(game).and_return(1000)

      expect(policy.send(:bot_may_buy_train?, game, buyer, train)).to be true
    end

    it 'buys early sibling 2-trains across cheaply for a two-corporation plan' do
      buyer = game.corporation_by_id('NC')
      seller = game.corporation_by_id('WAB')
      buyer.owner = player
      seller.owner = player
      buyer.set_cash(40, game.bank)
      seller.set_cash(160, game.bank)
      first_train = game.depot.min_depot_train
      game.buy_train(seller, first_train, :free)
      second_train = game.depot.min_depot_train
      game.buy_train(seller, second_train, :free)

      step = Game::G18IL::Step::BuyTrain.allocate
      step.instance_variable_set(:@game, game)
      allow(step).to receive(:buyable_trains).with(buyer).and_return([first_train])
      allow(step).to receive(:train_variant_helper) { |train, _entity| train.variants.values }
      allow(step).to receive(:spend_minmax).with(buyer, first_train).and_return([1, buyer.cash])
      allow(step).to receive(:must_buy_at_face_value?).with(first_train, buyer).and_return(false)
      allow(game).to receive(:operated_this_round?).and_call_original
      allow(game).to receive(:operated_this_round?).with(seller).and_return(true)

      decision = policy.send(:train_decision, game, step, buyer, %w[buy_train pass])

      expect(decision.action).to be_a(Engine::Action::BuyTrain)
      expect(decision.action.train).to eq(first_train)
      expect(decision.action.price).to eq(1)
    end

    it 'does not strip the last early train from a sibling corporation' do
      buyer = game.corporation_by_id('NC')
      seller = game.corporation_by_id('WAB')
      buyer.owner = player
      seller.owner = player
      buyer.set_cash(40, game.bank)
      train = game.depot.min_depot_train
      game.buy_train(seller, train, :free)

      allow(game).to receive(:operated_this_round?).and_call_original
      allow(game).to receive(:operated_this_round?).with(seller).and_return(true)

      expect(policy.send(:early_sibling_train_transfer?, game, buyer, train)).to be false
    end

    it 'blocks optional funding sales that expose a healthy presidency to takeover' do
      corporation = game.corporation_by_id('WAB')
      rival = game.players[1]
      corporation.owner = player
      corporation.ipoed = true
      player.set_cash(0, game.bank)
      rival.set_cash(200, game.bank)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      shares = corporation.shares.reject(&:president)
      game.share_pool.transfer_shares(ShareBundle.new(shares.first), player)
      shares.slice(1, 2).each { |share| game.share_pool.transfer_shares(ShareBundle.new(share), rival) }
      bundle = Struct.new(:corporation, :percent, :price).new(corporation, 10, 100)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)

      expect(policy.send(:funding_stock_sale_allowed?, game, step, player, bundle)).to be false
    end

    it 'blocks optional funding sales that drop a healthy presidency below its retention target' do
      corporation = game.corporation_by_id('C&EI')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.shares.reject(&:president).first), player)
      bundle = Struct.new(:corporation, :percent, :price).new(corporation, 10, 80)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)

      expect(policy.send(:healthy_presidency_takeover_exposure_after_sale?, game, player, bundle)).to be false
      expect(policy.send(:funding_stock_sale_allowed?, game, step, player, bundle)).to be false
    end

    it 'blocks discretionary sales of a healthy president share' do
      corporation = game.corporation_by_id('WAB')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      bundle = ShareBundle.new(corporation.presidents_share)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)

      expect(policy.send(:discretionary_stock_sale_allowed?, game, step, player, bundle)).to be false
    end

    it 'allows discretionary president-share sales from an unhealthy corporation' do
      corporation = game.corporation_by_id('WAB')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      bundle = ShareBundle.new(corporation.presidents_share)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:weak_stock_corporation?).and_return(false)
      allow(policy).to receive(:weak_stock_corporation?).and_return(false)
      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(true)

      expect(policy.send(:discretionary_stock_sale_allowed?, game, step, player, bundle)).to be true
    end

    it 'allows optional funding sales from a weak presidency' do
      corporation = game.corporation_by_id('WAB')
      rival = game.players[1]
      corporation.owner = player
      corporation.ipoed = true
      rival.set_cash(200, game.bank)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), player)
      shares = corporation.shares.reject(&:president)
      game.share_pool.transfer_shares(ShareBundle.new(shares.first), player)
      shares.slice(1, 2).each { |share| game.share_pool.transfer_shares(ShareBundle.new(share), rival) }
      bundle = Struct.new(:corporation, :percent, :price).new(corporation, 10, 100)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(true)

      expect(policy.send(:funding_stock_sale_allowed?, game, step, player, bundle)).to be true
    end

    it 'sells down before a weak presidency can be dumped onto the player' do
      corporation = game.corporation_by_id('C&EI')
      president = game.players[1]
      corporation.owner = president
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), president)
      shares = corporation.shares.reject(&:president)
      shares.first(3).each { |share| game.share_pool.transfer_shares(ShareBundle.new(share), president) }
      shares.drop(3).first(4).each { |share| game.share_pool.transfer_shares(ShareBundle.new(share), player) }
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:weak_stock_corporation?).and_return(false)
      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(true)

      decision = policy.send(:dump_risk_stock_sale_decision, game, step, player, %w[buy_shares sell_shares pass])

      expect(decision.action).to be_a(Engine::Action::SellShares)
      expect(decision.action.bundle.corporation).to eq(corporation)
      expect(decision.action.bundle.percent).to eq(30)
      expect(decision.reason).to include('avoid receiving')
    end

    it 'blocks endgame optional funding sales of premium shares for generic cash' do
      corporation = game.corporation_by_id('WAB')
      target = game.corporation_by_id('C&EI')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      allow(game).to receive(:last_set).and_return(true)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new(nil, nil)
      share = corporation.shares.reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:high_upside_engine?).with(game, corporation).and_return(false)

      expect(policy.send(
        :funding_stock_sale_allowed?,
        game,
        step,
        player,
        share.to_bundle,
        purpose: :launch,
        target_corporation: target,
      )).to be false
    end

    it 'allows the same premium share sale before the endgame window' do
      corporation = game.corporation_by_id('WAB')
      target = game.corporation_by_id('C&EI')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new(nil, nil)
      share = corporation.shares.reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:high_upside_engine?).with(game, corporation).and_return(false)

      expect(policy.send(
        :funding_stock_sale_allowed?,
        game,
        step,
        player,
        share.to_bundle,
        purpose: :launch,
        target_corporation: target,
      )).to be true
    end

    it 'allows endgame premium share sales for IC-specific funding' do
      corporation = game.corporation_by_id('WAB')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      allow(game).to receive(:last_set).and_return(true)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new(nil, nil)
      share = corporation.shares.reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:high_upside_engine?).with(game, corporation).and_return(false)

      expect(policy.send(
        :funding_stock_sale_allowed?,
        game,
        step,
        player,
        share.to_bundle,
        purpose: :ic,
        target_corporation: game.ic,
      )).to be true
    end

    it 'prioritizes buying a market share that can take over a healthy presidency' do
      corporation = game.corporation_by_id('WAB')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), rival)
      shares = corporation.shares.reject(&:president)
      game.share_pool.transfer_shares(ShareBundle.new(shares.first), player)
      game.share_pool.transfer_shares(ShareBundle.new(shares[1]), player)
      bundle = Struct.new(:corporation, :percent).new(corporation, 10)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:owns_permanent_train?).with(corporation).and_return(true)
      allow(policy).to receive(:financially_healthy_corporation?).with(game, corporation).and_return(true)

      expect(policy.send(:presidency_takeover_priority, game, player, bundle)).to be > 0
    end

    it 'prioritizes market shares that protect a viable corporation from closing' do
      corporation = game.corporation_by_id('G&CU')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.stock_market.market[0][4])
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(300, 'D', nil)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), rival)
      market_share = corporation.shares.reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(market_share), game.share_pool)
      bundle = market_share.to_bundle

      expect(policy.send(:market_close_protection_candidate?, game, corporation)).to be true
      expect(policy.send(:market_close_protection_priority, game, player, bundle)).to be >=
        described_class::MARKET_CLOSE_PROTECTION_PRIORITY
    end

    it 'does not protect a market-close candidate once a closure plan is remembered' do
      corporation = game.corporation_by_id('G&CU')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.stock_market.market[0][4])
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(300, 'D', nil)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), rival)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.shares.reject(&:president).first), game.share_pool)

      policy.send(:remember_closure_intent, game, corporation, reason: :stock_sale)

      expect(policy.send(:market_close_protection_candidate?, game, corporation)).to be false
    end

    it 'blocks optional funding sales that would put a viable corporation near closure' do
      corporation = game.corporation_by_id('WAB')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.stock_market.market[0][4])
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(300, 'D', nil)
      game.share_pool.transfer_shares(ShareBundle.new(corporation.presidents_share), rival)
      share = corporation.shares.reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      bundle = share.to_bundle
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      expect(policy.send(:funding_stock_sale_allowed?, game, step, player, bundle)).to be false

      policy.send(:remember_closure_intent, game, corporation, reason: :stock_sale)

      expect(policy.send(:funding_stock_sale_allowed?, game, step, player, bundle)).to be true
    end

    it 'rejects same-president train transfers before the seller has operated' do
      buyer = game.corporation_by_id('CBQ')
      seller = game.corporation_by_id('G&CU')
      buyer.owner = player
      seller.owner = player
      buyer.set_cash(400, game.bank)
      seller.set_cash(400, game.bank)
      game.stock_market.set_par(buyer, game.par_prices.find { |price| price.price == 80 })
      game.stock_market.set_par(seller, game.par_prices.find { |price| price.price == 100 })
      train = Struct.new(:owner, :price, :rusts_on, :obsolete_on) do
        def owned_by_corporation?
          true
        end
      end.new(seller, 400, nil, nil)

      allow(game).to receive(:operated_this_round?).with(seller).and_return(false)
      allow(policy).to receive(:strategic_train_transfer_target_price).with(game).and_return(740)

      expect(policy.send(:bot_may_buy_train?, game, buyer, train)).to be false
    end

    it 'includes an explorer profile for closure strategy experiments' do
      explorer = Game::G18IL::Bot::PolicyProfile.personality(:explorer)

      expect(explorer.name).to eq('Explorer')
      expect(explorer[:closure_strategy_weight]).to be > policy.profile[:closure_strategy_weight]
    end

    it 'rewards a low ten-share corporation paired with a smaller support corporation' do
      source = game.corporation_by_id('C&EI')
      support = game.corporation_by_id('NC')
      game.stock_market.set_par(source, game.par_prices.find { |price| price.price == 80 })

      score = policy.send(:closure_pair_synergy_score, game, [source, support])

      expect(score).to be_positive
    end

    it 'does not target a productive multi-train corporation as a closure source' do
      closure_policy = described_class.new(profile: Game::G18IL::Bot::PolicyProfile.personality(:explorer))
      corporation = game.corporation_by_id('WAB')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(160, '4+2C', nil)
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(300, '8', nil)

      allow(closure_policy).to receive(:connected_revenue_nodes).with(game, corporation).and_return(Array.new(4))
      allow(closure_policy).to receive(:imminent_train_rust_risk?).with(game, corporation).and_return(false)

      closure_policy.send(:remember_closure_intent, game, corporation, reason: :stock_sale)

      expect(closure_policy.send(:closure_source_candidate_score, game, corporation)).to eq(0)
      expect(closure_policy.closure_intent_for(game, corporation)).to be_nil
    end

    it 'does not continue a closure plan after a corporation owns a permanent train' do
      closure_policy = described_class.new(profile: Game::G18IL::Bot::PolicyProfile.personality(:explorer))
      corporation = game.corporation_by_id('NC')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 60 })
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(800, nil, nil)

      allow(closure_policy).to receive(:imminent_train_rust_risk?).with(game, corporation).and_return(false)
      closure_policy.send(:remember_closure_intent, game, corporation, reason: :stock_sale)

      expect(closure_policy.send(:closure_source_candidate_score, game, corporation)).to eq(0)
      expect(closure_policy.closure_intent_for(game, corporation)).to be_nil
    end

    it 'reserves cash for IC auctions once the line is nearly complete' do
      game.instance_variable_set(:@ic_line_completed_hexes, Array.new(described_class::IC_LINE_AUCTION_RESERVE_HEXES))

      expect(policy.send(:ic_auction_cash_reserve, game, player)).to eq(policy.profile[:ic_auction_cash_reserve])
    end

    it 'does not reserve cash for another IC auction in the final stock round' do
      game.instance_variable_set(:@ic_formation_triggered, true)
      game.instance_variable_set(:@last_set, true)

      expect(policy.send(:ic_auction_cash_reserve, game, player)).to eq(0)
    end

    it 'allows closure stripping train transfers at the legal minimum price' do
      closure_policy = described_class.new(profile: Game::G18IL::Bot::PolicyProfile.personality(:explorer))
      buyer = game.corporation_by_id('NC')
      seller = game.corporation_by_id('C&EI')
      buyer.owner = player
      seller.owner = player
      buyer.set_cash(100, game.bank)
      seller.set_cash(200, game.bank)
      game.stock_market.set_par(seller, game.par_prices.find { |price| price.price == 80 })
      train = Struct.new(:owner, :price, :rusts_on, :obsolete_on) do
        def owned_by_corporation?
          true
        end

        def from_depot?
          false
        end
      end.new(seller, 100, '4', nil)
      step = Object.new
      step.instance_variable_set(:@game, game)
      step.define_singleton_method(:spend_minmax) { |_entity, _train| [1, 100] }
      step.define_singleton_method(:must_buy_at_face_value?) { |_train, _entity| false }

      allow(game).to receive(:operated_this_round?).with(seller).and_return(true)
      allow(game).to receive(:operated_this_round?).with(buyer).and_return(false)

      expect(closure_policy.send(:closure_train_strip_transfer?, game, buyer, train)).to be true
      expect(closure_policy.send(:train_purchase_price, step, buyer, train, { name: '2' })).to eq(1)
    end

    it 'values retained cash and trains when evaluating a closure plan' do
      closure_policy = described_class.new(profile: Game::G18IL::Bot::PolicyProfile.personality(:explorer))
      corporation = game.corporation_by_id('C&EI')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })

      baseline = closure_policy.send(:closure_plan_score, game, corporation)
      corporation.set_cash(300, game.bank)
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(300, '4', nil)

      expect(closure_policy.send(:closure_plan_score, game, corporation)).to be > baseline
    end

    it 'prefers reopening an asset-rich closed corporation' do
      closure_policy = described_class.new(profile: Game::G18IL::Bot::PolicyProfile.personality(:explorer))
      corporation = game.corporation_by_id('NC')
      game.closed_corporations << corporation
      corporation.set_cash(240, game.bank)
      corporation.trains << Struct.new(:price, :rusts_on, :obsolete_on).new(300, '4', nil)
      price = Struct.new(:price).new(80)

      score = closure_policy.send(:launch_par_score, game, player, corporation, price)

      expect(score.first).to be_positive
    end

    it 'keeps a mature high-price corporation independent instead of merging into IC' do
      corporation = game.corporation_by_id('WAB')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(220, game.bank)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:merge_permanent_gap_matters?).with(game, corporation).and_return(false)
      allow(policy).to receive(:mature_permanent_route?).with(game, corporation).and_return(true)
      allow(policy).to receive(:ic_engine_dominant?).with(game).and_return(true)
      allow(policy).to receive(:closure_plan_score).with(game, corporation).and_return(0)

      expect(policy.send(:merge_score, game, corporation)).to be_negative
    end

    it 'still merges a mature low-price closure candidate into IC' do
      corporation = game.corporation_by_id('C&EI')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 40 })
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(57, game.bank)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:merge_permanent_gap_matters?).with(game, corporation).and_return(false)
      allow(policy).to receive(:mature_permanent_route?).with(game, corporation).and_return(true)
      allow(policy).to receive(:closure_plan_score).with(game, corporation).and_return(80)

      expect(policy.send(:merge_score, game, corporation)).to be_positive
    end

    it 'does not merge a healthy single-train corporation just because IC is trainless' do
      corporation = game.corporation_by_id('V')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(125, game.bank)
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('3', 160, '4+2C', nil)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:merge_permanent_gap_matters?).with(game, corporation).and_return(false)
      allow(policy).to receive(:mature_permanent_route?).with(game, corporation).and_return(false)

      expect(policy.send(:merge_score, game, corporation)).to be <= 0
    end

    it 'still merges a low-control closure candidate' do
      corporation = game.corporation_by_id('WAB')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(268, game.bank)
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('3', 160, '4+2C', nil)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:merge_permanent_gap_matters?).with(game, corporation).and_return(false)
      allow(policy).to receive(:mature_permanent_route?).with(game, corporation).and_return(false)
      allow(policy).to receive(:closure_plan_score).with(game, corporation).and_return(95)

      expect(policy.send(:merge_score, game, corporation)).to be_positive
    end

    it 'keeps an active multi-train operator independent at IC formation' do
      corporation = game.corporation_by_id('C&EI')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(120, game.bank)
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('3', 160, '4+2C', nil)
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('4', 240, 'D', nil)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:merge_permanent_gap_matters?).with(game, corporation).and_return(true)
      allow(policy).to receive(:ic_engine_dominant?).with(game).and_return(false)
      allow(policy).to receive(:connected_revenue_nodes).with(game, corporation).and_return(Array.new(5) { Object.new })

      expect(policy.send(:merge_score, game, corporation)).to be_negative
    end

    it 'still merges a trainless corporation that needs IC to preserve value' do
      corporation = game.corporation_by_id('WAB')
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(20, game.bank)

      allow(policy).to receive(:weak_stock_corporation?).with(game, corporation).and_return(false)
      allow(policy).to receive(:merge_permanent_gap_matters?).with(game, corporation).and_return(true)
      allow(policy).to receive(:ic_engine_dominant?).with(game).and_return(false)
      allow(policy).to receive(:connected_revenue_nodes).with(game, corporation).and_return([])

      expect(policy.send(:merge_score, game, corporation)).to be_positive
    end

    it 'always takes an IC merger share when it is offered' do
      game.stock_market.set_par(game.ic, game.par_prices.find { |price| price.price == 80 })
      game.ic.ipoed = true
      ic_name = game.ic.name
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::ExchangeChoicePlayer }
      step.define_singleton_method(:choices) do
        ['Receive $999', "Receive a 10% share of #{ic_name}"]
      end

      decision = policy.send(:merger_compensation_decision, game, step, player, %w[choose])

      expect(decision.action.choice).to include('10% share')
      expect(decision.reason).to include('IC share')
    end

    it 'makes the final missing H7 IC Line completion urgent' do
      corporation = game.corporation_by_id('C&EI')
      h7 = game.hex_by_id('H7')
      completed = (game.class::IC_LINE_ORIENTATION.keys - ['H7']).map { |hex_id| game.hex_by_id(hex_id) }
      game.instance_variable_set(:@ic_line_completed_hexes, completed)
      tile = Object.new

      allow(policy).to receive(:ic_line_connections).with(game, h7, h7.tile).and_return(1)
      allow(policy).to receive(:ic_line_connections).with(game, h7, tile).and_return(2)

      score = policy.send(:ic_line_progress_score, game, corporation, h7, tile)

      expect(score).to be > 10_000
    end

    it 'prefers an H7 yellow placement that can later complete the IC Line' do
      corporation = game.corporation_by_id('WAB')
      h7 = game.hex_by_id('H7')
      dead_end = game.tiles.find { |tile| tile.name == 'K12' }.dup.rotate!(5)
      completable = game.tiles.find { |tile| tile.name == 'K13' }.dup.rotate!(1)

      dead_end_score = policy.send(:track_candidate_score, game, h7, dead_end, 0, corporation)
      completable_score = policy.send(:track_candidate_score, game, h7, completable, 0, corporation)

      expect(completable_score).to be > dead_end_score
      expect(policy.send(:ic_line_future_completion_possible?, game, h7, dead_end)).to be false
      expect(policy.send(:ic_line_future_completion_possible?, game, h7, completable)).to be true
    end

    it 'does not use Advanced Track before a normal track lay' do
      round = Struct.new(:num_laid_track, :upgraded_track).new(0, false)
      track_game = Struct.new(:round).new(round)
      company = Struct.new(:sym).new('AT')
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::SpecialTrack }
      step.define_singleton_method(:tile_lay_available?) { |_entity| true }

      expect(policy.send(:special_track_decision, track_game, step, company)).to be_nil
    end

    it 'waits on Advanced Track after one normal yellow lay' do
      round = Struct.new(:num_laid_track, :upgraded_track).new(1, false)
      track_game = Struct.new(:round).new(round)
      company = Struct.new(:sym).new('AT')

      expect(policy.send(:advanced_track_useful_now?, track_game, company)).to be false
    end

    it 'uses Advanced Track after one upgrade only for another upgrade' do
      round = Struct.new(:num_laid_track, :upgraded_track).new(1, true)
      track_game = Struct.new(:round).new(round)
      company = Struct.new(:sym).new('AT')
      white_hex = Struct.new(:tile).new(Struct.new(:color).new(:white))
      green_hex = Struct.new(:tile).new(Struct.new(:color).new(:green))

      expect(policy.send(:advanced_track_useful_now?, track_game, company)).to be true
      expect(policy.send(:advanced_track_candidate_allowed?, track_game, company, white_hex)).to be false
      expect(policy.send(:advanced_track_candidate_allowed?, track_game, company, green_hex)).to be true
    end

    it 'allows Advanced Track as a third tile lay' do
      round = Struct.new(:num_laid_track, :upgraded_track).new(2, false)
      track_game = Struct.new(:round).new(round)
      company = Struct.new(:sym).new('AT')
      white_hex = Struct.new(:tile).new(Struct.new(:color).new(:white))

      expect(policy.send(:advanced_track_useful_now?, track_game, company)).to be true
      expect(policy.send(:advanced_track_candidate_allowed?, track_game, company, white_hex)).to be true
    end

    it 'prioritizes high-upside engine shares over ordinary shares' do
      high_upside = game.corporation_by_id('WAB')
      ordinary = game.corporation_by_id('C&EI')
      rival = game.players[1]
      [high_upside, ordinary].each do |corporation|
        corporation.owner = rival
        corporation.ipoed = true
        game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
        game.share_pool.transfer_shares(ShareBundle.new(corporation.shares.reject(&:president).first), game.share_pool)
      end
      high_upside.trains.concat([
                                  Struct.new(:rusts_on, :obsolete_on).new('D', nil),
                                  Struct.new(:rusts_on, :obsolete_on).new(nil, nil),
                                ])
      player.set_cash(500, game.bank)
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::BaseBuySellParShares }
      step.define_singleton_method(:can_buy?) { |_entity, _bundle| true }

      allow(policy).to receive(:connected_revenue_nodes).with(game, high_upside).and_return(Array.new(4) { Object.new })
      allow(policy).to receive(:connected_revenue_nodes).with(game, ordinary).and_return([])

      decision = policy.send(:share_purchase_decision, game, step, player, %w[buy_shares pass])

      expect(decision.action.bundle.corporation).to eq(high_upside)
    end

    it 'does not sell the last meaningful share of a high-upside engine for optional funding' do
      corporation = game.corporation_by_id('WAB')
      rival = game.players[1]
      corporation.owner = rival
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      share = corporation.shares.reject(&:president).first
      game.share_pool.transfer_shares(ShareBundle.new(share), player)
      corporation.trains.concat([
                                  Struct.new(:rusts_on, :obsolete_on).new('D', nil),
                                  Struct.new(:rusts_on, :obsolete_on).new(nil, nil),
                                ])
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| true }

      allow(policy).to receive(:connected_revenue_nodes).with(game, corporation).and_return(Array.new(4) { Object.new })

      expect(policy.send(:funding_stock_sale_allowed?, game, step, player, share.to_bundle)).to be false
    end

    it 'prefers a 0+3C over a 4 for any three-city network' do
      corporation = game.corporation_by_id('CBQ')
      city = Struct.new(:value) do
        def city?
          true
        end

        def revenue
          { yellow: value, green: value, brown: value, gray: value }
        end
      end
      train = Struct.new(:distance, :owner).new([], nil)
      four = {
        name: '4',
        distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                   { 'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4 }],
        price: 240,
        rusts_on: 'D',
      }
      zero_three_city = {
        name: '0+3C',
        distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                   { 'nodes' => ['city'], 'pay' => 3, 'visit' => 3 }],
        price: 320,
        rusts_on: '8',
      }

      allow(policy).to receive(:connected_revenue_nodes)
        .with(game, corporation)
        .and_return([city.new(10), city.new(20), city.new(30)])

      zero_three_score = policy.send(:train_candidate_score, game, train, zero_three_city, 320, nil, corporation)
      four_score = policy.send(:train_candidate_score, game, train, four, 240, nil, corporation)

      expect(zero_three_score).to be > four_score
    end

    it 'strongly prefers a 3 train for a corporation holding only 2-trains' do
      corporation = game.corporation_by_id('CBQ')
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      train = Struct.new(:distance, :owner).new([], nil)
      two = {
        name: '2',
        distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                   { 'nodes' => %w[city offboard], 'pay' => 2, 'visit' => 2 }],
        price: 80,
        rusts_on: '4',
      }
      three = {
        name: '3',
        distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                   { 'nodes' => %w[city offboard], 'pay' => 3, 'visit' => 3 }],
        price: 160,
        rusts_on: '4+2C',
      }

      two_score = policy.send(:train_candidate_score, game, train, two, 80, nil, corporation)
      three_score = policy.send(:train_candidate_score, game, train, three, 160, nil, corporation)

      expect(three_score).to be > two_score
    end

    it 'converts a two-share corporation when conversion can fund a 3 before its 2-trains rust' do
      corporation = game.corporation_by_id('IR')
      corporation.owner = player
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      corporation.set_cash(40, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Conversion }

      allow(policy).to receive(:projected_post_conversion_funding)
        .with(game, corporation, 5)
        .and_return({ purchase_proceeds: 80, issue_proceeds: 80, total_proceeds: 160 })
      allow(policy).to receive(:three_train_options)
        .with(game, corporation)
        .and_return([{ name: '3', price: 160 }])
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)

      decision = policy.send(:conversion_decision, game, step, corporation, %w[convert pass])

      expect(decision.action).to be_a(Engine::Action::Convert)
      expect(decision.reason).to include('fund the 3 before 2-trains rust')
    end

    it 'adds no train acceleration pressure for the leading player' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player

      allow(game).to receive(:player_value) { |candidate| candidate == player ? 1_200 : 900 }

      expect(policy.send(:relative_train_pressure, game, corporation)).to eq(0)
    end

    it 'adds train acceleration pressure for a trailing player' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player

      allow(game).to receive(:player_value) { |candidate| candidate == player ? 800 : 1_200 }

      expect(policy.send(:relative_train_pressure, game, corporation)).to be_positive
    end

    it 'rewards a trailing player for buying a train that advances and rusts the roster' do
      corporation = game.corporation_by_id('CBQ')
      leader_corporation = game.corporation_by_id('WAB')
      leader = game.players[1]
      corporation.owner = player
      leader_corporation.owner = leader
      leader_corporation.trains << Struct.new(:rusts_on).new('4')
      variant = { name: '4' }
      depot_train = Struct.new(:variants).new({ '4' => variant })

      allow(game).to receive(:player_value) { |candidate| candidate == player ? 800 : 1_400 }
      allow(game.depot).to receive(:depot_trains).and_return([depot_train])

      expect(policy.send(:train_acceleration_bonus, game, corporation, variant)).to be_positive
    end

    it 'rewards buying a replacement train before all current trains rust' do
      corporation = game.corporation_by_id('CBQ')
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new('4', nil)
      variant = { name: '4' }

      expect(policy.send(:rust_replacement_train_bonus, game, corporation, variant))
        .to eq(described_class::RUST_REPLACEMENT_TRAIN_BONUS)
    end

    it 'does not reward a rust replacement train when an existing train survives' do
      corporation = game.corporation_by_id('CBQ')
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new('4', nil)
      corporation.trains << Struct.new(:rusts_on, :obsolete_on).new('5', nil)
      variant = { name: '4' }

      expect(policy.send(:rust_replacement_train_bonus, game, corporation, variant)).to eq(0)
    end

    it 'issues toward an affordable 3 train when it only owns 2-trains' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      corporation.ipoed = true
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      corporation.set_cash(120, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      share = corporation.shares.reject(&:president).first
      bundle = Struct.new(:shares, :num_shares, :share_price, :price).new([share], 1, corporation.share_price, 80)
      step = Game::G18IL::Step::IssueShares.allocate
      step.define_singleton_method(:issuable_shares) { |_entity| [bundle] }

      allow(policy).to receive(:affordable_permanent_train_after_issue).with(game, corporation, 80).and_return(nil)
      allow(policy).to receive(:affordable_three_train_after_issue)
        .with(game, corporation, 80)
        .and_return({ name: '3', price: 160 })
      allow(policy).to receive(:affordable_zero_three_city_train_after_issue).with(game, corporation, 80).and_return(nil)
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)
      allow(policy).to receive(:cbq_needs_stl_permit_issue?).with(game, corporation, 80).and_return(false)
      allow(policy).to receive(:closure_issue_pressure?).with(game, corporation).and_return(false)
      allow(policy).to receive(:route_creation_funding_needed?).with(game, corporation, 80).and_return(false)

      decision = policy.send(:share_issue_decision, game, step, corporation, %w[sell_shares])

      expect(decision.action).to be_a(Engine::Action::SellShares)
      expect(decision.reason).to include('3 train')
    end

    it 'issues toward a 3 train fund even when one issue is not enough' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      corporation.ipoed = true
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      corporation.set_cash(40, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 40 })
      share = corporation.shares.reject(&:president).first
      bundle = Struct.new(:shares, :num_shares, :share_price, :price).new([share], 1, corporation.share_price, 40)
      step = Game::G18IL::Step::IssueShares.allocate
      step.define_singleton_method(:issuable_shares) { |_entity| [bundle] }

      allow(policy).to receive(:affordable_permanent_train_after_issue).with(game, corporation, 40).and_return(nil)
      allow(policy).to receive(:affordable_three_train_after_issue).with(game, corporation, 40).and_return(nil)
      allow(policy).to receive(:affordable_zero_three_city_train_after_issue).with(game, corporation, 40).and_return(nil)
      allow(policy).to receive(:three_train_fund_target)
        .with(game, corporation)
        .and_return({ name: '3', price: 160 })
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)
      allow(policy).to receive(:cbq_needs_stl_permit_issue?).with(game, corporation, 40).and_return(false)
      allow(policy).to receive(:closure_issue_pressure?).with(game, corporation).and_return(false)
      allow(policy).to receive(:route_creation_funding_needed?).with(game, corporation, 40).and_return(false)

      decision = policy.send(:share_issue_decision, game, step, corporation, %w[sell_shares])

      expect(decision.action).to be_a(Engine::Action::SellShares)
      expect(decision.reason).to include('build toward')
    end

    it 'half pays when a small retain still avoids the stock movement loss' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 8, share_direction: :up, share_times: 1 },
          half: { corporation: 20, per_share: 4, share_direction: :up, share_times: 1 },
          withhold: { corporation: 40, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('half')
    end

    it 'prefers half pay when it retains cash and still gains stock value' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 8, share_direction: :up, share_times: 1 },
          half: { corporation: 200, per_share: 40, share_direction: :right, share_times: 1 },
          withhold: { corporation: 400, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('half')
    end

    it 'withholds when a large retain outweighs weak dividend movement' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 8, share_direction: :up, share_times: 1 },
          half: { corporation: 40, per_share: 8, share_direction: :up, share_times: 1 },
          withhold: { corporation: 400, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('withhold')
    end

    it 'does not fully withhold a 2-only corporation to afford a 3 train' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      corporation.set_cash(100, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 8, share_direction: :up, share_times: 1 },
          half: { corporation: 40, per_share: 4, share_direction: :up, share_times: 1 },
          withhold: { corporation: 70, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(policy).to receive(:dividend_train_options)
        .with(game, corporation)
        .and_return([{ name: '3', price: 160, permanent: false }])

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('half')
      expect(decision.reason).to include('highest-scored dividend option')
    end

    it 'does not withhold toward a duplicate 3 train once a corporation already owns one' do
      corporation = game.corporation_by_id('C&EI')
      corporation.owner = player
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('2', 80, '4', nil)
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('3', 160, '4+2C', nil)
      corporation.set_cash(100, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 8, share_direction: :up, share_times: 1 },
          half: { corporation: 40, per_share: 4, share_direction: :up, share_times: 1 },
          withhold: { corporation: 70, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(policy).to receive(:dividend_train_options)
        .with(game, corporation)
        .and_return([{ name: '3', price: 160, permanent: false }])

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).not_to eq('withhold')
      expect(decision.reason).to include('highest-scored dividend option')
    end

    it 'does not choose a dividend option that would close a viable corporation' do
      corporation = game.corporation_by_id('C&EI')
      corporation.owner = player
      corporation.ipoed = true
      corporation.trains << Struct.new(:name, :price, :rusts_on, :obsolete_on).new('3', 160, '4+2C', nil)
      game.stock_market.set_par(corporation, game.stock_market.market[0][2])
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 0, share_direction: :right, share_times: 1 },
          half: { corporation: 10, per_share: 0, share_direction: :right, share_times: 1 },
          withhold: { corporation: 1_000, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(policy).to receive(:dividend_train_options).with(game, corporation).and_return([])

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).not_to eq('withhold')
      expect(policy.send(:dividend_resulting_share_price, game, corporation, step.dividend_options(corporation)[:withhold]).type)
        .to eq(:close)
    end

    it 'half pays a 2-only corporation when that affords a 3 train' do
      corporation = game.corporation_by_id('CBQ')
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      corporation.set_cash(100, game.bank)
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0 },
          half: { corporation: 60 },
          withhold: { corporation: 70 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(policy).to receive(:dividend_train_options)
        .with(game, corporation)
        .and_return([{ name: '3', price: 160, permanent: false }])

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('half')
      expect(decision.reason).to include('2-trains rust')
    end

    it 'withholds for a permanent train before paying out for a closure plan' do
      corporation = game.corporation_by_id('G&CU')
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('4', 'D', nil)
      corporation.set_cash(551, game.bank)
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0 },
          half: { corporation: 98 },
          withhold: { corporation: 170 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(policy).to receive(:closure_hot_run?).with(game, corporation).and_return(true)
      allow(policy).to receive(:dividend_train_options)
        .with(game, corporation)
        .and_return([{ name: 'D', price: 700, permanent: true }])

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('withhold')
      expect(decision.reason).to include('permanent train')
    end

    it 'does not withhold toward a 3 train when one withhold is not enough' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      corporation.trains << Struct.new(:name, :rusts_on, :obsolete_on).new('2', '4', nil)
      corporation.set_cash(20, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 8, share_direction: :up, share_times: 1 },
          half: { corporation: 20, per_share: 4, share_direction: :up, share_times: 1 },
          withhold: { corporation: 50, per_share: 0, share_direction: :left, share_times: 1 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(policy).to receive(:dividend_train_options)
        .with(game, corporation)
        .and_return([{ name: '3', price: 160, permanent: false }])
      allow(policy).to receive(:three_train_options)
        .with(game, corporation)
        .and_return([{ name: '3', price: 160 }])

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).not_to eq('withhold')
      expect(decision.reason).to include('highest-scored dividend option')
    end

    it 'half pays a frozen sold-out corporation by default' do
      corporation = game.corporation_by_id('CBQ')
      game.frozen_corporations << corporation
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Dividend }
      step.define_singleton_method(:dividend_options) do |_entity|
        {
          payout: { corporation: 0, per_share: 20 },
          half: { corporation: 50, per_share: 10 },
          withhold: { corporation: 100, per_share: 0 },
        }
      end
      step.define_singleton_method(:dividend_types) { %i[payout half withhold] }

      allow(corporation).to receive(:num_ipo_shares).and_return(0)
      allow(corporation).to receive(:num_ipo_reserved_shares).and_return(0)
      allow(corporation).to receive(:num_treasury_shares).and_return(0)

      decision = policy.send(:dividend_decision, game, step, corporation, %w[dividend])

      expect(decision.action.kind).to eq('half')
      expect(decision.reason).to include('frozen and sold out')
    end

    it 'issues toward an affordable 0+3C for a strong city network' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      corporation.set_cash(280, game.bank)
      train = Struct.new(:variants, :price).new({
                                                  '4' => {
                                                    name: '4',
                                                    distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                                                               { 'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4 }],
                                                    price: 240,
                                                    rusts_on: 'D',
                                                  },
                                                  '0+3C' => {
                                                    name: '0+3C',
                                                    distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                                                               { 'nodes' => ['city'], 'pay' => 3, 'visit' => 3 }],
                                                    price: 320,
                                                    rusts_on: '8',
                                                  },
                                                }, 240)

      allow(policy).to receive(:strong_zero_three_city_network?).with(game, corporation).and_return(true)
      allow(game.depot).to receive(:depot_trains).and_return([train])
      allow(game).to receive(:discountable_trains_for).with(corporation).and_return([])

      option = policy.send(:affordable_zero_three_city_train_after_issue, game, corporation, 40)

      expect(option).to include(name: '0+3C', price: 320)
    end

    it 'scraps the cheapest train when that opens a permanent train after the reduced run' do
      corporation = game.corporation_by_id('CBQ')
      cheap_train = Struct.new(:id, :name, :price, :rusts_on, :obsolete_on, :distance).new('2-1', '2', 80, '4', nil, 2)
      expensive_train = Struct.new(:id, :name, :price, :rusts_on, :obsolete_on, :distance).new('3-1', '3', 180, '5', nil, 3)
      corporation.trains.concat([cheap_train, expensive_train])
      corporation.set_cash(500, game.bank)
      step = Object.new
      step.define_singleton_method(:scrappable_trains) { |_entity| [cheap_train, expensive_train] }

      allow(game).to receive(:train_limit).with(corporation).and_return(2)
      allow(policy).to receive(:permanent_train_options_after_scrap)
        .with(game, corporation, cheap_train)
        .and_return([{ name: 'D', price: 740 }])
      allow(policy).to receive(:route_revenue_without_train).with(game, corporation, nil).and_return(300)
      allow(policy).to receive(:route_revenue_without_train).with(game, corporation, cheap_train).and_return(260)

      train, permanent, lost_revenue = policy.send(:scrap_for_permanent_candidate, game, step, corporation)

      expect(train).to eq(cheap_train)
      expect(permanent).to include(name: 'D', price: 740)
      expect(lost_revenue).to eq(40)
    end

    it 'does not scrap for a permanent train when the lost route revenue is too high' do
      corporation = game.corporation_by_id('CBQ')
      cheap_train = Struct.new(:id, :name, :price, :rusts_on, :obsolete_on, :distance).new('2-1', '2', 80, '4', nil, 2)
      expensive_train = Struct.new(:id, :name, :price, :rusts_on, :obsolete_on, :distance).new('3-1', '3', 180, '5', nil, 3)
      corporation.trains.concat([cheap_train, expensive_train])
      corporation.set_cash(500, game.bank)
      step = Object.new
      step.define_singleton_method(:scrappable_trains) { |_entity| [cheap_train, expensive_train] }

      allow(game).to receive(:train_limit).with(corporation).and_return(2)
      allow(policy).to receive(:permanent_train_options_after_scrap)
        .with(game, corporation, cheap_train)
        .and_return([{ name: 'D', price: 740 }])
      allow(policy).to receive(:route_revenue_without_train).with(game, corporation, nil).and_return(500)
      allow(policy).to receive(:route_revenue_without_train).with(game, corporation, cheap_train).and_return(240)

      expect(policy.send(:scrap_for_permanent_candidate, game, step, corporation)).to be_nil
    end

    it 'issues a share to fund route-forming track before protecting train cash' do
      corporation = game.corporation_by_id('C&EI')
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(80, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      share = corporation.shares.reject(&:president).first
      bundle = Struct.new(:shares, :num_shares, :share_price, :price).new([share], 1, corporation.share_price, 80)
      step = Game::G18IL::Step::IssueShares.allocate
      step.define_singleton_method(:issuable_shares) { |_entity| [bundle] }

      allow(policy).to receive(:affordable_permanent_train_after_issue).with(game, corporation, 80).and_return(nil)
      allow(policy).to receive(:affordable_zero_three_city_train_after_issue).with(game, corporation, 80).and_return(nil)
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)
      allow(policy).to receive(:cbq_needs_stl_permit_issue?).with(game, corporation, 80).and_return(false)
      allow(policy).to receive(:closure_issue_pressure?).with(game, corporation).and_return(false)
      allow(policy).to receive(:route_creation_funding_needed?).with(game, corporation, 80).and_return(true)

      decision = policy.send(:share_issue_decision, game, step, corporation, %w[sell_shares])

      expect(decision.action).to be_a(Engine::Action::SellShares)
      expect(decision.reason).to include('route-forming track')
    end

    it 'sells a non-president share to fund opening a strategic concession corporation' do
      sale_corporation = game.corporation_by_id('CBQ')
      target_corporation = game.corporation_by_id('NC')
      player.set_cash(100, game.bank)
      share_price = Struct.new(:price).new(100)
      target = { corporation: target_corporation, share_price: share_price, required_cash: 200, score: 200 }
      share = sale_corporation.shares.reject(&:president).first
      share.owner = player
      bundle = Struct.new(:shares, :percent, :num_shares, :presidents_share, :price).new([share], 10, 1, false, 100)
      step = Object.new

      allow(step).to receive(:is_a?).with(Game::G18IL::Step::BaseBuySellParShares).and_return(true)
      allow(policy).to receive(:strategic_concession_launch_target).with(game, step, player).and_return(target)
      allow(policy).to receive(:concession_launch_sale_candidates)
        .with(game, step, player, target)
        .and_return([[sale_corporation, bundle]])

      decision = policy.send(:concession_launch_funding_sale_decision, game, step, player, %w[sell_shares])

      expect(decision.action).to be_a(Engine::Action::SellShares)
      expect(decision.reason).to include('fund opening NC')
    end

    it 'does not reserve second-concession launch cash over capitalizing a trainless presidency' do
      corporation = game.corporation_by_id('C&EI')
      target_corporation = game.corporation_by_id('RI')
      corporation.owner = player
      corporation.ipoed = true
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 80 })
      share = corporation.shares.reject(&:president).find { |candidate| candidate.owner == corporation }
      share.buyable = true
      target = { corporation: target_corporation, required_cash: 200, score: 200 }
      step = Object.new
      step.define_singleton_method(:can_buy?) { |_entity, _bundle| true }

      allow(policy).to receive(:strategic_concession_launch_target).with(game, step, player).and_return(target)

      expect(policy.send(:concession_launch_cash_reserve, game, step, player)).to eq(0)
    end

    it 'does not reserve cash for a concession launch that cannot be reached this stock round' do
      target_corporation = game.corporation_by_id('RI')
      player.set_cash(115, game.bank)
      target = { corporation: target_corporation, required_cash: 200, score: 200 }
      step = Object.new
      step.define_singleton_method(:can_sell?) { |_entity, _bundle| false }

      allow(policy).to receive(:strategic_concession_launch_target).with(game, step, player).and_return(target)

      expect(policy.send(:concession_launch_cash_reserve, game, step, player)).to eq(0)
    end

    it 'prefers a high par for a late second corporation permanent-train capitalization plan' do
      existing = game.corporation_by_id('CBQ')
      target = game.corporation_by_id('C&EI')
      concession = game.company_by_id('C&EI')
      existing.owner = player
      existing.ipoed = true
      game.stock_market.set_par(existing, game.par_prices.find { |price| price.price == 80 })
      concession.owner = player
      player.companies << concession
      player.set_cash(900, game.bank)

      allow(game).to receive(:phase).and_return(Struct.new(:name).new('4A'))
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)

      price_100 = Struct.new(:price).new(100)
      price_150 = Struct.new(:price).new(150)
      score_100 = policy.send(:launch_par_score, game, player, target, price_100)
      score_150 = policy.send(:launch_par_score, game, player, target, price_150)

      expect(score_150 <=> score_100).to eq(1)
    end

    it 'keeps a five-player investor from accidentally taking a presidency before its phase-4A founder auction' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      corporations = %w[NC IR G&CU C&EI].map { |id| five_player_game.corporation_by_id(id) }
      corporations.zip(five_player_game.players.first(4)).each do |corporation, owner|
        corporation.owner = owner
        corporation.ipoed = true
      end
      target = corporations.first
      president = target.owner
      bundle = Struct.new(:corporation, :percent).new(target, target.share_percent)
      holding = Struct.new(:percent)
      allow(president).to receive(:shares_of).with(target).and_return([holding.new(target.presidents_percent)])
      allow(investor).to receive(:shares_of).with(target).and_return([holding.new(target.presidents_percent)])

      expect(
        five_player_policy.send(:investor_purchase_preserves_non_presidency?, five_player_game, investor, bundle),
      ).to be false

      allow(five_player_game).to receive(:phase).and_return(Struct.new(:name).new('4A'))

      expect(
        five_player_policy.send(:investor_purchase_preserves_non_presidency?, five_player_game, investor, bundle),
      ).to be false

      allow(investor).to receive(:shares_of).with(target).and_return([holding.new(target.share_percent)])

      expect(
        five_player_policy.send(:investor_purchase_preserves_non_presidency?, five_player_game, investor, bundle),
      ).to be true
    end

    it 'lets a presidency-free five-player investor fund a phase-4A 150-par launch from its portfolio' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      %w[NC IR G&CU RI].zip(five_player_game.players.first(4)).each do |id, owner|
        corporation = five_player_game.corporation_by_id(id)
        corporation.owner = owner
        corporation.ipoed = true
      end
      concession = five_player_game.company_by_id('C&EI')
      corporation = five_player_game.corporation_by_id('C&EI')
      investor.set_cash(200, five_player_game.bank)
      five_player_game.phase.next! until five_player_game.phase.name == '4A'
      allow(five_player_policy).to receive(:investor_founder_sale_capacity)
        .with(five_player_game, investor)
        .and_return(300)
      allow(five_player_policy).to receive(:projected_investor_founder_train)
        .with(five_player_game, corporation, anything)
        .and_return({
                      name: '5',
                      price: 520,
                      variant: { name: '5', price: 520, rusts_on: nil, obsolete_on: nil },
                      ahead_purchases: [],
                    })

      par = five_player_policy.send(
        :investor_founder_launch_par,
        five_player_game,
        investor,
        corporation,
        available_cash: 500,
      )

      expect(five_player_policy.send(:investor_founder_pivot?, five_player_game, investor)).to be true
      expect(par.price).to eq(150)
      expect(five_player_policy.send(:concession_opening_cost, five_player_game, investor, concession)).to eq(150)
    end

    it 'lets a late investor pivot once most other high-count players are committed' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      %w[NC IR G&CU].zip(five_player_game.players.first(3)).each do |id, owner|
        corporation = five_player_game.corporation_by_id(id)
        corporation.owner = owner
        corporation.ipoed = true
      end
      five_player_game.phase.next! until five_player_game.phase.name == '4A'

      expect(five_player_policy.send(:investor_founder_pivot?, five_player_game, investor)).to be true
    end

    it 'marks a presidency-free investor launch so stock sales can fund it incrementally' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      %w[NC IR G&CU RI].zip(five_player_game.players.first(4)).each do |id, owner|
        corporation = five_player_game.corporation_by_id(id)
        corporation.owner = owner
        corporation.ipoed = true
      end
      concession = five_player_game.company_by_id('C&EI')
      concession.owner = investor
      investor.companies << concession
      investor.set_cash(200, five_player_game.bank)
      five_player_game.phase.next! until five_player_game.phase.name == '4A'
      allow(five_player_policy).to receive(:investor_founder_sale_capacity)
        .with(five_player_game, investor)
        .and_return(300)
      allow(five_player_policy).to receive(:investor_founder_sale_capacity)
        .with(five_player_game, investor, step: nil)
        .and_return(300)
      allow(five_player_policy).to receive(:projected_investor_founder_train)
        .with(five_player_game, five_player_game.corporation_by_id('C&EI'), anything)
        .and_return({
                      name: '5',
                      price: 520,
                      variant: { name: '5', price: 520, rusts_on: nil, obsolete_on: nil },
                      ahead_purchases: [],
                    })
      allow(five_player_policy).to receive(:cheapest_available_permanent_train).with(five_player_game).and_return(nil)

      target = five_player_policy.send(:strategic_concession_launch_target, five_player_game, nil, investor)

      expect(target[:corporation].id).to eq('C&EI')
      expect(target[:share_price].price).to eq(150)
      expect(target[:required_cash]).to eq(450)
      expect(target[:founder_plan][:personal_share_units]).to eq(3)
      expect(target[:founder_plan][:issue_proceeds]).to eq(150)
      expect(target[:founder_plan][:projected_train][:name]).to eq('5')
      expect(target[:founder_pivot]).to be true
    end

    it 'uses one planned issue instead of six shares for a founder launch train plan' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      investor = five_player_game.players.last
      %w[NC IR G&CU RI].zip(five_player_game.players.first(4)).each do |id, owner|
        corporation = five_player_game.corporation_by_id(id)
        corporation.owner = owner
        corporation.ipoed = true
      end
      corporation = five_player_game.corporation_by_id('C&EI')
      five_player_game.phase.next! until five_player_game.phase.name == '4A'
      share_price = five_player_game.par_prices.find { |price| price.price == 150 }
      allow(five_player_policy).to receive(:projected_investor_founder_train)
        .with(five_player_game, corporation, share_price)
        .and_return({
                      name: '5',
                      price: 520,
                      variant: { name: '5', price: 520, rusts_on: nil, obsolete_on: nil },
                      ahead_purchases: [],
                    })

      expect(
        five_player_policy.send(
          :investor_founder_capitalization_plan,
          five_player_game,
          investor,
          corporation,
          share_price,
          available_cash: 449,
        ),
      ).to be_nil

      plan = five_player_policy.send(
        :investor_founder_capitalization_plan,
        five_player_game,
        investor,
        corporation,
        share_price,
        available_cash: 450,
      )

      expect(plan[:required_cash]).to eq(450)
      expect(plan[:personal_share_units]).to eq(3)
      expect(plan[:issue_proceeds]).to eq(150)
      expect(plan[:projected_treasury]).to eq(520)
    end

    it 'projects later train availability from likely operating-order purchases ahead' do
      five_player_game = Game::G18IL::Game.new(%w[A B C D E])
      five_player_policy = described_class.new
      ahead = five_player_game.corporation_by_id('CBQ')
      target = five_player_game.corporation_by_id('C&EI')
      ahead.owner = five_player_game.players.first
      ahead.ipoed = true
      ahead.floated = true
      ahead.set_cash(240, five_player_game.bank)
      five_player_game.phase.next! until five_player_game.phase.name == '4A'
      five_player_game.stock_market.set_par(ahead, five_player_game.par_prices.find { |price| price.price == 150 })
      share_price = five_player_game.par_prices.find { |price| price.price == 120 }
      first_four = five_player_game.depot.upcoming.find { |train| train.name == '4' }
      later_trains = five_player_game.depot.upcoming.reject { |train| ['Rogers (1+1)', '2', '3', '4'].include?(train.name) }
      five_player_game.depot.upcoming.replace([first_four, *later_trains])

      projection = five_player_policy.send(:projected_investor_founder_train, five_player_game, target, share_price)

      expect(projection[:name]).to eq('5')
      expect(projection[:ahead_purchases]).to include(hash_including(corporation: 'CBQ', name: '4', price: 240))
    end

    it 'uses a planned issue instead of six shares for a late pressure launch' do
      existing = game.corporation_by_id('CBQ')
      target = game.corporation_by_id('C&EI')
      concession = game.company_by_id('C&EI')
      existing.owner = player
      existing.ipoed = true
      game.stock_market.set_par(existing, game.par_prices.find { |price| price.price == 80 })
      concession.owner = player
      player.companies << concession

      allow(game).to receive(:phase).and_return(Struct.new(:name).new('4A'))
      allow(policy).to receive(:train_pressure_window?).with(game).and_return(true)
      allow(policy).to receive(:projected_investor_founder_train)
        .with(game, target, anything)
        .and_return({
                      name: '5',
                      price: 520,
                      variant: { name: '5', price: 520, rusts_on: nil, obsolete_on: nil },
                      ahead_purchases: [],
                    })

      expect(policy.send(:concession_launch_cash_required, game, player, target, 150)).to eq(450)
    end

    it 'allows a saturated second concession when it can create late train pressure' do
      existing = game.corporation_by_id('IR')
      owned_concession = game.company_by_id('IR')
      target = game.corporation_by_id('C&EI')
      target_concession = game.company_by_id('C&EI')
      existing.owner = player
      existing.ipoed = true
      game.stock_market.set_par(existing, game.par_prices.find { |price| price.price == 100 })
      owned_concession.owner = player
      player.companies << owned_concession
      player.set_cash(900, game.bank)

      allow(game).to receive(:phase).and_return(Struct.new(:name).new('4A'))
      allow(policy).to receive(:second_concession_saturated?).with(game, player).and_return(true)
      allow(policy).to receive(:second_corporation_bailout_motive?).with(game, player).and_return(false)
      allow(policy).to receive(:train_pressure_window?).with(game).and_return(true)
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)
      allow(policy).to receive(:projected_investor_founder_train)
        .with(game, target, anything)
        .and_return({
                      name: '5',
                      price: 520,
                      variant: { name: '5', price: 520, rusts_on: nil, obsolete_on: nil },
                      ahead_purchases: [],
                    })

      expect(policy.send(:concession_auction_startable?, game, player, target_concession)).to be true
      expect(policy.send(:second_concession_plan_value, game, player, target_concession)).to be_positive
    end

    it 'marks a late high-par launch as a train-pressure target' do
      existing = game.corporation_by_id('IR')
      target = game.corporation_by_id('C&EI')
      concession = game.company_by_id('C&EI')
      existing.owner = player
      existing.ipoed = true
      game.stock_market.set_par(existing, game.par_prices.find { |price| price.price == 100 })
      concession.owner = player
      player.companies << concession
      player.set_cash(900, game.bank)

      allow(game).to receive(:phase).and_return(Struct.new(:name).new('4A'))
      allow(policy).to receive(:train_pressure_window?).with(game).and_return(true)
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)
      allow(policy).to receive(:projected_investor_founder_train)
        .with(game, target, anything)
        .and_return({
                      name: '5',
                      price: 520,
                      variant: { name: '5', price: 520, rusts_on: nil, obsolete_on: nil },
                      ahead_purchases: [],
                    })

      target = policy.send(:strategic_concession_launch_target, game, nil, player)

      expect(target[:corporation].id).to eq('C&EI')
      expect(target[:share_price].price).to eq(150)
      expect(target[:train_pressure]).to be true
    end

    it 'converts a five-share corporation when conversion can fund a pressure train' do
      corporation = game.corporation_by_id('CBQ')
      corporation.owner = player
      corporation.ipoed = true
      corporation.set_cash(120, game.bank)
      game.stock_market.set_par(corporation, game.par_prices.find { |price| price.price == 100 })
      step = Object.new
      step.define_singleton_method(:is_a?) { |klass| klass == Game::G18IL::Step::Conversion }

      allow(policy).to receive(:projected_post_conversion_funding)
        .with(game, corporation, 10)
        .and_return({ purchase_proceeds: 300, issue_proceeds: 150, total_proceeds: 450 })
      allow(policy).to receive(:train_pressure_window?).with(game).and_return(true)
      allow(policy).to receive(:train_pressure_target_train).with(game).and_return({ name: '5', price: 520 })
      allow(policy).to receive(:cheapest_available_permanent_train).with(game).and_return(nil)

      decision = policy.send(:conversion_decision, game, step, corporation, %w[convert pass])

      expect(decision.action).to be_a(Engine::Action::Convert)
      expect(decision.reason).to include('pressure the market with the 5')
    end

    it 'uses the 18IL token cost when evaluating launches on a cloned base game' do
      base_game = Struct.new(:closed_corporations).new([])

      expect(policy.send(:launch_token_cost, base_game, game.corporation_by_id('CBQ'))).to eq(40)
      expect(policy.send(:launch_token_cost, base_game, game.corporation_by_id('C&EI'))).to eq(80)
    end
  end
end
