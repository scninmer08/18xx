# frozen_string_literal: true

require_relative '../../part/city'

module Engine
  module Game
    module G1872
      module City
        def tokened_by?(corporation, types: [])
          token_proxy = corporation&.respond_to?(:token_proxy_corporation) && corporation.token_proxy_corporation
          return true if token_proxy && super(token_proxy, types: types)

          super
        end
      end
    end
  end
end

Engine::Part::City.prepend(Engine::Game::G1872::City)
