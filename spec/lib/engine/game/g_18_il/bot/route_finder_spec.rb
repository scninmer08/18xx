# frozen_string_literal: true

require 'json'
require 'spec_helper'
require_relative '../../../../../../lib/engine/game/g_18_il/bot/route_finder'

module Engine
  describe Game::G18IL::Bot::RouteFinder do
    let(:game) { Game::G18IL::Game.new(%w[A B C D]) }
    let(:finder) { described_class.new(game) }
    let(:train) { Struct.new(:distance).new(distance) }

    def stop(type)
      Struct.new(:type).new(type)
    end

    it 'allows long plus-city trains to include unlimited town visits beyond the old hard cap' do
      distance = [
        { 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
        { 'nodes' => %w[city offboard], 'pay' => 6, 'visit' => 6 },
      ]
      train = Struct.new(:distance).new(distance)
      stops = Array.new(4) { stop('town') } + Array.new(6) { stop('city') }

      expect(finder.send(:route_stop_limit, train, stops)).to eq(10)
    end

    it 'keeps D-train route searches bounded without the old eight-stop limit' do
      train = Struct.new(:distance).new(999)
      stops = Array.new(40) { stop('town') }

      expect(finder.send(:route_stop_limit, train, stops)).to eq(described_class::MAX_LONG_ROUTE_STOPS)
    end

    it 'keeps ordinary short trains on the smaller validation window' do
      short_train = Struct.new(:distance).new([
                                                { 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                                                { 'nodes' => %w[city offboard], 'pay' => 2, 'visit' => 2 },
                                              ])
      long_train = Struct.new(:distance).new(999)

      expect(finder.send(:long_train?, short_train)).to be false
      expect(finder.send(:long_train?, long_train)).to be true
    end

    it 'uses long-route search settings for Pullman and route-extension train names' do
      train = Struct.new(:name, :distance)
      short_distance = [
        { 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
        { 'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4 },
      ]

      %w[4+2C 5+1C 5+2C 6 6+1C 9].each do |name|
        expect(finder.send(:long_train?, train.new(name, short_distance))).to be true
      end
    end

    it 'rejects repeated-city route candidates before route revenue validation' do
      train = Struct.new(:distance).new(2)
      left = Object.new
      right = Object.new
      connection = [
        { left: left, right: right },
        { left: right, right: left },
      ]

      expect(finder.send(:connection_reuses_city?, train, connection)).to be true
    end

    it 'allows the local loop route shape permitted by route validation' do
      train = Struct.new(:distance) do
        def local?
          true
        end
      end.new(1)
      stop = Object.new
      connection = [{ left: stop, right: stop }]

      expect(finder.send(:connection_reuses_city?, train, connection)).to be false
    end

    it 'keeps early short route candidates when high-estimate paths are invalid' do
      data = JSON.parse(File.read('lib/engine/game/g_18_il/bot/reports/replays/replay_058.json'))
      names = data.fetch('players').to_h { |player| [player.fetch('id'), player.fetch('name')] }
      replay = Game::G18IL::Game.new(
        names,
        seed: data.dig('settings', 'seed'),
        optional_rules: data.dig('settings', 'optional_rules'),
        actions: data.fetch('actions'),
        at_action: 221,
      )
      wab = replay.corporation_by_id('WAB')
      train = replay.route_trains(wab).first

      revenues = described_class.new(replay).routes_for(wab, train, limit: 10).map(&:revenue)

      expect(revenues).to include(50, 40)
    end
  end
end
