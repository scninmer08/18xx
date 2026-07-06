# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../../../lib/engine/game/g_18_il/bot/baseline_policy'

module Engine
  describe Game::G18IL::Bot::BaselinePolicy do
    let(:game) { Game::G18IL::Game.new(%w[A B C D]) }
    let(:player) { game.players.first }
    let(:policy) { described_class.new }
    let(:private_company) { game.company_by_id('GTL') }

    it 'does not open auctions for privates without a corporation that can eventually acquire them' do
      expect(policy.send(:auction_startable?, game, player, private_company)).to be false
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
  end
end
