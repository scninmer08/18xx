# frozen_string_literal: true

require_relative '../../corporation'

module Engine
  module Game
    module G1872
      class Corporation < Engine::Corporation
        def mark_operated!
          @g1872_operated = true
        end

        def operated?
          !!@g1872_operated
        end

        def assign_shell_identity!(root, path)
          label = path.join('.')
          @name = "#{root.name}-#{label}"
          self.full_name = "#{root.full_name} - Shell #{label}"
          assign_shell_logo!(root, path)
          self.color = root.color
          self.text_color = root.text_color
          @tokens = root.tokens
        end

        def token_proxy_corporation
          return nil unless type == :shell

          tokens.first&.corporation
        end

        private

        def assign_shell_logo!(root, _path)
          @logo_filename = root.logo_filename
          @logo = root.logo
          @simple_logo = root.simple_logo
        end
      end
    end
  end
end
