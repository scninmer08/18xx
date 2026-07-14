# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../../../lib/engine/game/g_18_il/bot/runner'

module Engine
  describe Game::G18IL::Bot::Runner do
    it 'records IC formation timing when formation is triggered' do
      owner = double('owner', name: 'Bot 2')
      trigger_entity = double('trigger_entity', name: 'Advanced Track', company?: true, owner: owner)
      round = double('round', name: 'Operating Round', round_num: 2)
      phase = double('phase', name: '5')
      game = double(
        'game',
        ic_formation_triggered?: true,
        ic_trigger_entity: trigger_entity,
        round: round,
        turn: 4,
        phase: phase,
      )
      runner = described_class.new(game, policy: double('policy'))
      runner.instance_variable_set(:@events, [])
      runner.instance_variable_set(:@ic_formation_triggered, false)

      2.times { runner.send(:observe_ic_formation) }

      expect(runner.instance_variable_get(:@events)).to eq([
                                                             {
                                                               event: 'ic_formation',
                                                               turn: 4,
                                                               round: 'Operating Round',
                                                               round_num: 2,
                                                               operating_round: '4.2',
                                                               phase: '5',
                                                               trigger_entity: 'Advanced Track',
                                                               trigger_actor: 'Bot 2',
                                                             },
                                                           ])
    end

    it 'records the triggering action for presidency changes' do
      old_president = double('old_president', name: 'Bot 1', player?: true)
      new_president = double('new_president', name: 'Bot 2', player?: true)
      corporation = double('corporation', name: 'WAB', owner: old_president)
      round = double('round', name: 'Stock Round')
      game = double(
        'game',
        corporations: [corporation],
        closed_corporations: [],
        round: round,
        turn: 3,
      )
      runner = described_class.new(game, policy: double('policy'))
      runner.instance_variable_set(:@events, [])
      runner.instance_variable_set(:@presidencies, 'WAB' => 'Bot 1')
      allow(corporation).to receive(:owner).and_return(new_president)

      runner.send(
        :observe_presidency_changes,
        {
          action: 'sell_shares',
          entity: 'Bot 1',
          step: 'Buy/Sell Shares',
          reason: 'Sells down weak WAB',
          corporation: 'WAB',
          percent: 50,
          price: 400,
        },
      )

      expect(runner.instance_variable_get(:@events)).to eq([
                                                             {
                                                               event: 'presidency',
                                                               corporation: 'WAB',
                                                               player: 'Bot 2',
                                                               turn: 3,
                                                               round: 'Stock Round',
                                                               trigger_action: 'sell_shares',
                                                               trigger_entity: 'Bot 1',
                                                               trigger_step: 'Buy/Sell Shares',
                                                               trigger_reason: 'Sells down weak WAB',
                                                               trigger_corporation: 'WAB',
                                                               trigger_percent: 50,
                                                               trigger_price: 400,
                                                             },
                                                           ])
    end
  end
end
