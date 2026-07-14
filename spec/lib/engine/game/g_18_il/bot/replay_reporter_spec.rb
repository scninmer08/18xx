# frozen_string_literal: true

require 'json'
require 'tempfile'

require 'spec_helper'
require_relative '../../../../../../lib/engine/game/g_18_il/bot'

module Engine
  describe Game::G18IL::Bot::ReplayReporter do
    def replay_data(actions: 12)
      result = Game::G18IL::Bot.run(players: 4, seed: 33_777, max_actions: actions)
      game = result.game
      {
        'id' => "18il_test_#{game.seed}",
        'title' => game.class.title,
        'players' => game.players.map { |player| { 'id' => player.id, 'name' => player.name } },
        'settings' => { 'seed' => game.seed, 'optional_rules' => [] },
        'status' => 'active',
        'actions' => game.raw_actions,
      }
    end

    def with_replay_file(data)
      Tempfile.create(['18il-replay', '.json']) do |file|
        file.write(JSON.pretty_generate(data))
        file.flush
        yield file.path
      end
    end

    it 'builds batch-style stats for an unfinished replay' do
      data = replay_data

      with_replay_file(data) do |path|
        report = described_class.new(path).run

        expect(report.summary[:status]).to eq('in_progress')
        expect(report.summary[:actions_total]).to eq(data['actions'].size)
        expect(report.summary[:actions_replayed]).to eq(data['actions'].size)
        expect(report.summary[:metrics][:auction_bids]).to be_positive
        expect(report.format).to include('18IL Replay Report')
        expect(report.format).to include('18IL Bot Batch-Style Stats')
      end
    end

    it 'can stop at a source action id' do
      data = replay_data
      cutoff = data['actions'][3].fetch('id')

      with_replay_file(data) do |path|
        report = described_class.new(path, at_action: cutoff).run

        expect(report.summary[:detail]).to include("Replay stopped at action #{cutoff}")
        expect(report.summary.dig(:failure, :last_action, :action_id)).to eq(cutoff)
        expect(report.actions_replayed).to eq(4)
      end
    end
  end
end
