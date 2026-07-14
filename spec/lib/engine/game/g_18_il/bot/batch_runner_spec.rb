# frozen_string_literal: true

require 'json'
require 'spec_helper'
require 'tmpdir'
require_relative '../../../../../../lib/engine/game/g_18_il/bot/batch_runner'

module Engine
  describe Game::G18IL::Bot::BatchResult do
    def batch_summary(seed:, ic_formation:, train_events: [], train_runs: [], closure_events: [],
                      opening_execution: [], ic_non_formation: nil, player_count: 2)
      {
        seed: seed,
        status: 'finished',
        detail: 'Game completed',
        player_count: player_count,
        actions_taken: 1,
        turn: 5,
        profiles: [],
        players: Array.new(player_count) do |index|
          { seat: index + 1, name: "Bot #{index + 1}", rank: index + 1, value: 1000 - (index * 100) }
        end,
        corporations: [],
        presidency_events: [],
        closure_events: closure_events,
        par_events: [],
        opening_execution: opening_execution,
        train_events: train_events,
        train_runs: train_runs,
        dividends: [],
        ic_formation: ic_formation,
        ic_non_formation: ic_non_formation,
        peak_player_cash: 0,
        metrics: {},
        par_mix: {},
        train_mix: {},
        track_tile_usage: {},
        failure: nil,
      }
    end

    def batch_result(summaries)
      described_class.new(
        games_requested: summaries.size,
        players: 2,
        optional_rules: [],
        first_seed: summaries.first[:seed],
        summaries: summaries,
      )
    end

    it 'summarizes IC formation phase and operating round' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: { phase: '5', operating_round: '4.2' },
                              ),
                              batch_summary(
                                seed: 2,
                                ic_formation: { phase: '6', operating_round: '5.1' },
                              ),
                            ])

      expect(result.aggregate[:ic_formation_timing]).to eq(
        games: 2,
        completed_games: 2,
        percentage: 100.0,
        phase_mix: { '5' => 1, '6' => 1 },
        operating_round_mix: { '4.2' => 1, '5.1' => 1 },
      )
      expect(result.format).to include(
        'IC formation timing: games=2 / 2 (100.0%), phases: 5=1, 6=1; ORs: 4.2=1, 5.1=1',
      )
    end

    it 'reports none when IC never forms' do
      result = batch_result([
                              batch_summary(seed: 1, ic_formation: nil),
                            ])

      expect(result.aggregate[:ic_formation_timing][:games]).to eq(0)
      expect(result.format).to include('IC formation timing: none')
    end

    it 'summarizes why IC did not form' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                ic_non_formation: {
                                  reason: 'IC Line incomplete',
                                  phase: '5',
                                  operating_round: '4.1',
                                  completed_count: 7,
                                  required_count: 10,
                                  missing_hexes: %w[E20 E22 F19],
                                },
                              ),
                              batch_summary(
                                seed: 2,
                                ic_formation: nil,
                                ic_non_formation: {
                                  reason: 'IC Line completed in phase D',
                                  phase: 'D',
                                  completed_count: 10,
                                  required_count: 10,
                                  missing_hexes: [],
                                },
                              ),
                            ])

      expect(result.aggregate[:ic_non_formation]).to eq(
        games: 2,
        report_games: 2,
        percentage: 100.0,
        reason_mix: { 'IC Line incomplete' => 1, 'IC Line completed in phase D' => 1 },
        phase_mix: { '5' => 1, 'D' => 1 },
        average_completed_hexes: 8.5,
        required_count: 10,
        missing_hexes: { 'E20' => 1, 'E22' => 1, 'F19' => 1 },
      )
      expect(result.format).to include(
        'IC non-formation: games=2 / 2 (100.0%), reasons: IC Line completed in phase D=1, ' \
        'IC Line incomplete=1; phases: 5=1, D=1; avg completed=8.5 / 10; ' \
        'common missing: E20=1, E22=1, F19=1',
      )
      expect(result.format).to include(
        "IC non-formation games:\n" \
        '    Seed 1: IC Line incomplete, phase 5, OR 4.1, completed 7/10, missing E20, E22, F19' \
        "\n" \
        '    Seed 2: IC Line completed in phase D, phase D, turn 5, completed 10/10, missing none',
      )
    end

    it 'summarizes closure diagnostics' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                closure_events: [
                                  {
                                    event: 'corporation_close',
                                    corporation: 'WAB',
                                    closure_reason: 'planned_market_close',
                                    train_count: 2,
                                    permanent_train: false,
                                    active_operator: true,
                                    last_route_revenue: 180,
                                    trigger_action: 'sell_shares',
                                    closure_intent: { reason: 'stock_sale', turn: 3 },
                                  },
                                  {
                                    event: 'corporation_close',
                                    corporation: 'C&EI',
                                    closure_reason: 'ic_merge',
                                    train_count: 0,
                                    permanent_train: false,
                                    active_operator: false,
                                    trigger_action: 'transition_to_next_round',
                                  },
                                ],
                              ),
                            ])

      expect(result.aggregate[:closure_diagnostics]).to eq(
        total: 2,
        planned: 1,
        unplanned: 1,
        with_trains: 1,
        active_operators: 1,
        with_permanent: 0,
        average_last_route_revenue: 180.0,
        closure_reason_mix: { 'planned_market_close' => 1, 'ic_merge' => 1 },
        trigger_action_mix: { 'sell_shares' => 1, 'transition_to_next_round' => 1 },
        intent_reason_mix: { 'stock_sale' => 1, 'none' => 1 },
      )
      expect(result.format).to include(
        'Corporation closure diagnostics: closure_plan=1, no_closure_plan=1, with_trains=1, ' \
        'active_operators=1, permanent=0, avg_last_route=180.0; reasons: ic_merge=1, ' \
        'planned_market_close=1; triggers: sell_shares=1, ' \
        'transition_to_next_round=1; intents: none=1, stock_sale=1',
      )
    end

    it 'ranks city revenue hotspots by direct city stop revenue' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                train_runs: [
                                  {
                                    train: '2',
                                    corporation: 'A',
                                    revenue: 70,
                                    stops: [
                                      { hex: 'E8', location_name: 'Chicago', type: 'city', revenue: 40 },
                                      { hex: 'D5', location_name: 'Springfield', type: 'city', revenue: 20 },
                                      { hex: 'G1', location_name: 'Galena', type: 'town', revenue: 10 },
                                    ],
                                  },
                                  {
                                    train: '3',
                                    corporation: 'B',
                                    revenue: 100,
                                    stops: [
                                      { hex: 'E8', location_name: 'Chicago', type: 'city', revenue: 50 },
                                      { hex: 'C12', location_name: 'Peoria', type: 'city', revenue: 30 },
                                    ],
                                  },
                                ],
                              ),
                            ])

      expect(result.aggregate[:city_hotspots].first(3)).to eq([
                                                                {
                                                                  hex: 'E8',
                                                                  location_name: 'Chicago',
                                                                  revenue: 90,
                                                                  hits: 2,
                                                                  label: 'Chicago (E8)',
                                                                  average_revenue: 45.0,
                                                                },
                                                                {
                                                                  hex: 'C12',
                                                                  location_name: 'Peoria',
                                                                  revenue: 30,
                                                                  hits: 1,
                                                                  label: 'Peoria (C12)',
                                                                  average_revenue: 30.0,
                                                                },
                                                                {
                                                                  hex: 'D5',
                                                                  location_name: 'Springfield',
                                                                  revenue: 20,
                                                                  hits: 1,
                                                                  label: 'Springfield (D5)',
                                                                  average_revenue: 20.0,
                                                                },
                                                              ])
      expect(result.format).to include(
        'City revenue hotspots:',
        'Chicago (E8) revenue=90 hits=2 avg=45.0',
      )
    end

    it 'reports opening execution diagnostics' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                opening_execution: [
                                  {
                                    corporation: 'C&EI',
                                    president: 'Bot 1',
                                    concession_auction_price: 45,
                                    par_price: 80,
                                    president_units_first_or: 3,
                                    presidency_target_units: 3,
                                    takeover_depth_first_or: 4,
                                    treasury_after_first_sr: 240,
                                    first_train: { train: '2', price: 80 },
                                    first_route_revenue: 100,
                                  },
                                ],
                              ),
                            ])

      expect(result.aggregate[:opening_execution].first[:seed]).to eq(1)
      expect(result.format).to include('Opening execution:')
      expect(result.format).to include(
        'Seed 1 C&EI president=Bot 1 auction=$45 par=$80 units=3/3 depth=4 treasury=$240 ' \
        'train=2@$80 first_route=$100 takeover=none closed=none',
      )
    end

    it 'separates NC Rogers revenue from the first bought-train route' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                opening_execution: [
                                  {
                                    corporation: 'NC',
                                    president: 'Bot 1',
                                    concession_auction_price: 60,
                                    par_price: 100,
                                    president_units_first_or: 2,
                                    presidency_target_units: 2,
                                    takeover_depth_first_or: 3,
                                    treasury_after_first_sr: 200,
                                    first_train: { train: '2', price: 80 },
                                    first_route_revenue: 30,
                                    first_bought_train_route_revenue: 50,
                                  },
                                ],
                              ),
                            ])

      expect(result.format).to include(
        'Seed 1 NC president=Bot 1 auction=$60 par=$100 units=2/2 depth=3 treasury=$200 ' \
        'train=2@$80 first_route=$30 first_bought_route=$50 takeover=none closed=none',
      )
    end

    it 'labels opening presidency changes caused by president sales' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                opening_execution: [
                                  {
                                    corporation: 'WAB',
                                    president: 'Bot 3',
                                    concession_auction_price: 10,
                                    par_price: 80,
                                    president_units_first_or: 5,
                                    presidency_target_units: 3,
                                    takeover_depth_first_or: 6,
                                    treasury_after_first_sr: 640,
                                    first_train: { train: '2', price: 80 },
                                    first_route_revenue: 80,
                                    takeover: {
                                      player: 'Bot 1',
                                      reason: 'president_sale',
                                      round: 'Stock Round',
                                    },
                                  },
                                ],
                              ),
                            ])

      expect(result.format).to include(
        'Seed 1 WAB president=Bot 3 auction=$10 par=$80 units=5/3 depth=6 treasury=$640 ' \
        'train=2@$80 first_route=$80 takeover=Bot 1/president_sale/Stock Round closed=none',
      )
    end

    it 'combines Pullman-struck train data into the main train buckets in train order' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                train_events: [
                                  { event: 'purchased', train: '4', price: 300, turn: 1 },
                                  { event: 'purchased', train: '0+3C', price: 300, turn: 1 },
                                  { event: 'purchased', train: '5', price: 500, turn: 1 },
                                  { event: 'purchased', train: '4+2C', price: 600, turn: 1 },
                                  { event: 'purchased', train: '5+1C', price: 800, turn: 1 },
                                ],
                                train_runs: [
                                  { train: '4', original_train: '4', revenue: 120 },
                                  { train: '0+3C', original_train: '0+3C', revenue: 180 },
                                  { train: '4+2C', original_train: '4+2C', revenue: 240 },
                                  { train: '4', original_train: '4+2C', revenue: 160 },
                                  { train: '5', original_train: '5', revenue: 210 },
                                  { train: '5+1C', original_train: '5+1C', revenue: 320 },
                                  { train: '5', original_train: '5+1C', revenue: 220 },
                                ],
                              ),
                            ])

      expect(result.aggregate[:train_performance]).to include(
        '4+2C + Pullman 4' => include(average_runs: 2.0, average_revenue: 200.0),
        '5+1C + Pullman 5' => include(average_runs: 2.0, average_revenue: 270.0),
      )
      expect(result.aggregate[:train_performance]).not_to have_key('4 (Pullman 4+2C)')
      expect(result.aggregate[:train_performance]).not_to have_key('5 (Pullman 5+1C)')

      format = result.format
      expect(format.index('4 runs=1.0 avg=120.0')).to be < format.index('0+3C runs=1.0 avg=180.0')
      expect(format.index('0+3C runs=1.0 avg=180.0')).to be < format.index('5 runs=1.0 avg=210.0')
      expect(format.index('5 runs=1.0 avg=210.0')).to be < format.index('4+2C + Pullman 4 runs=2.0 avg=200.0')
      expect(format.index('5 bought=1.0 exported=0.0 runs=1.0')).to be <
        format.index('4+2C + Pullman 4 bought=1.0 exported=0.0 runs=2.0')
      expect(format).not_to include('Pullman combined train route revenue')
      expect(format).not_to include('Pullman struck train runs by corporation')
    end

    it 'summarizes train value trends separately by player count' do
      result = described_class.new(
        games_requested: 2,
        players: [2, 3],
        optional_rules: [],
        first_seed: 1,
        summaries: [
          batch_summary(
            seed: 1,
            player_count: 2,
            ic_formation: nil,
            train_events: [{ event: 'purchased', train: '2', price: 80 }],
            train_runs: [{ train: '2', original_train: '2', revenue: 160 }],
          ),
          batch_summary(
            seed: 2,
            player_count: 3,
            ic_formation: nil,
            train_events: [{ event: 'purchased', train: '2', price: 80 }],
            train_runs: [{ train: '2', original_train: '2', revenue: 80 }],
          ),
        ],
      )

      expect(result.aggregate[:player_counts]).to eq(2 => 1, 3 => 1)
      expect(result.aggregate[:player_count_breakdown][2][:train_lifecycle]['2'][:revenue_per_price]).to eq(2.0)
      expect(result.aggregate[:player_count_breakdown][3][:train_lifecycle]['2'][:revenue_per_price]).to eq(1.0)

      expect(result.format).to include('Games: 2 | Players: 2, 3 mixed | Seeds: 1-2')
      expect(result.format).to include('Player-count trends:')
      expect(result.format).to include('2p games=1 avg_actions=1.0 corps/game=0.0 corps/player=0.0')
      expect(result.format).to include('train rev/$: 2=2.0')
      expect(result.format).to include('3p games=1 avg_actions=1.0 corps/game=0.0 corps/player=0.0')
      expect(result.format).to include('train rev/$: 2=1.0')
    end

    it 'flags plain 4-train runs in the final operating set' do
      result = batch_result([
                              batch_summary(
                                seed: 1,
                                ic_formation: nil,
                                train_runs: [
                                  { train: '4', original_train: '4', corporation: 'IC', turn: 4, revenue: 180 },
                                  { train: '4', original_train: '4', corporation: 'IC', turn: 5, round_num: 1, revenue: 240 },
                                  { train: '4', original_train: '4+2C', corporation: 'IC', turn: 5, round_num: 2, revenue: 260 },
                                  { train: '5', original_train: '5', corporation: 'NC', turn: 5, round_num: 2, revenue: 300 },
                                ],
                              ),
                            ])

      expect(result.aggregate[:late_non_permanent_four_runs]).to eq([
                                                                      {
                                                                        seed: 1,
                                                                        corporation: 'IC',
                                                                        operating_round: '5.1',
                                                                        revenue: 240,
                                                                      },
                                                                    ])
      expect(result.format).to include('Late non-permanent 4 runs: seed 1 IC OR 5.1 revenue=240')
    end
  end

  describe Game::G18IL::Bot::BatchRunner do
    fake_result = Struct.new(:status, :game, keyword_init: true)

    fake_game_class = Class.new do
      def self.title
        '18IL'
      end

      attr_reader :seed, :optional_rules, :players, :raw_actions

      def initialize(seed, player_count = 2)
        @seed = seed
        @optional_rules = []
        @players = Array.new(player_count) { |index| Struct.new(:id, :name).new("player_#{index + 1}", "Bot #{index + 1}") }
        @raw_actions = [{ 'type' => 'pass', 'entity' => 'player_1' }]
      end
    end

    runner_class = Class.new(described_class) do
      define_method(:initialize) do |fake_game_class:, fake_result:, **kwargs|
        @fake_game_class = fake_game_class
        @fake_result = fake_result
        super(**kwargs)
      end

      private

      def policy_for_seed(_seed)
        nil
      end

      def run_bot(seed, _policy)
        @fake_result.new(status: :finished, game: @fake_game_class.new(seed, current_player_count))
      end

      def summarize(result, seed, _policy)
        {
          seed: seed,
          status: result.status.to_s,
          detail: 'Game completed',
          actions_taken: 1,
        }
      end
    end

    it 'writes one hotseat JSON per completed batch game and records elapsed time' do
      allow(Process).to receive(:respond_to?).and_call_original
      allow(Process).to receive(:respond_to?).with(:fork).and_return(false)

      Dir.mktmpdir('18il-batch-jsons') do |dir|
        result = runner_class.new(
          fake_game_class: fake_game_class,
          fake_result: fake_result,
          games: 1,
          players: 2,
          optional_rules: [],
          first_seed: 12_345,
          max_actions: 10,
          policy_factory: nil,
          game_json_dir: dir,
        ).run

        summary = result.summaries.first
        expect(summary[:elapsed_seconds]).to be >= 0
        expect(summary[:game_json_path]).to eq(File.join(dir, 'game_001_seed_12345.json'))

        data = JSON.parse(File.read(summary[:game_json_path]))
        expect(data['settings']['seed']).to eq(12_345)
        expect(data['players'].map { |player| player['name'] }).to eq(['Bot 1', 'Bot 2'])
        expect(data['actions']).to eq([{ 'type' => 'pass', 'entity' => 'player_1' }])
      end
    end

    it 'cycles configured player counts across games' do
      allow(Process).to receive(:respond_to?).and_call_original
      allow(Process).to receive(:respond_to?).with(:fork).and_return(false)

      result = runner_class.new(
        fake_game_class: fake_game_class,
        fake_result: fake_result,
        games: 3,
        players: [2, 3],
        optional_rules: [],
        first_seed: 12_345,
        max_actions: 10,
        policy_factory: nil,
      ).run

      expect(result.players).to eq([2, 3])
      expect(result.summaries.map { |summary| summary[:player_count] }).to eq([2, 3, 2])
    end
  end
end
