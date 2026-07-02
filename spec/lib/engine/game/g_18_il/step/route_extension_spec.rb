# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../../../lib/engine/game/g_18_il/step/route_extension'

describe Engine::Game::G18IL::Step::RouteExtension do
  subject(:step) { described_class.allocate }

  def train(name, nodes: %w[city offboard], distance: 3)
    Struct.new(:name, :distance).new(
      name,
      [{ 'nodes' => ['town'], 'pay' => 99, 'visit' => 99 },
       { 'nodes' => nodes, 'pay' => distance, 'visit' => distance }],
    )
  end

  it 'extends a conventional train by one city or offboard stop' do
    extended_train = train('3')

    step.send(:extend_train!, extended_train)

    expect(extended_train.name).to eq('4')
    expect(extended_train.distance.last).to eq(
      'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4
    )
  end

  it 'extends the non-C portion of a 0+3C train and permits an offboard stop' do
    extended_train = train('0+3C', nodes: ['city'])

    step.send(:extend_train!, extended_train)

    expect(extended_train.name).to eq('1+3C')
    expect(extended_train.distance.last).to eq(
      'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4
    )
  end

  it 'extends the non-C portion of a 4+2C train' do
    extended_train = train('4+2C', distance: 6)

    step.send(:extend_train!, extended_train)

    expect(extended_train.name).to eq('5+2C')
    expect(extended_train.distance.last['visit']).to eq(7)
  end

  it 'leaves a D train unchanged' do
    extended_train = Struct.new(:name, :distance).new('D', 999)

    step.send(:extend_train!, extended_train)

    expect(extended_train.name).to eq('D')
    expect(extended_train.distance).to eq(999)
  end
end
