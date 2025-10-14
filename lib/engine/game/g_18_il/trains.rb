# frozen_string_literal: true

module Engine
  module Game
    module G18IL
      module Trains
        TRAINS = [
            {
              name: 'Rogers (1+1)',
              distance: [
              { 'nodes' => ['town'], 'pay' => 1, 'visit' => 1 },
              { 'nodes' => ['city'], 'pay' => 1, 'visit' => 1 },
                ],
              price: 0,
              reserved: true,
              num: 1,
            },
            {
              name: '2',
              distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                         { 'nodes' => %w[city offboard], 'pay' => 2, 'visit' => 2 }],
              price: 80,
              rusts_on: '4',
              num: 99,
            },
            {
              name: '3',
              distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                         { 'nodes' => %w[city offboard], 'pay' => 3, 'visit' => 3 }],
              price: 160,
              rusts_on: '5+1C',
              num: 6,
            },
            {
              name: '4',
              distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                         { 'nodes' => %w[city offboard], 'pay' => 4, 'visit' => 4 }],
              price: 240,
              rusts_on: 'D',
              num: 5,
              variants: [{
                name: '0+3C',
                distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                           { 'nodes' => ['city'], 'pay' => 3, 'visit' => 3 }],
                price: 320,
                rusts_on: '6',
              }],
            },
            {
              name: '4+2C',
              distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                         { 'nodes' => %w[city offboard], 'pay' => 6, 'visit' => 6 }],
              price: 800,
              num: 4,
            },
            {
              name: '5+1C',
              distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                         { 'nodes' => %w[city offboard], 'pay' => 6, 'visit' => 6 }],
              price: 720,
              num: 3,
            },
            {
              name: '6',
              distance: [{ 'nodes' => %w[town], 'pay' => 99, 'visit' => 99 },
                         { 'nodes' => %w[city offboard], 'pay' => 6, 'visit' => 6 }],
              price: 640,
              num: 2,
            },
            {
              name: 'D',
              distance: 999,
              price: 1000,
              num: 99,
              available_on: '6',
              events: [
                { 'type' => 'signal_end_game' },
                ],
              discount: { '4+2C' => 250, '5+1C' => 250, '6' => 250 },
            },
         ].freeze
      end
    end
  end
end
