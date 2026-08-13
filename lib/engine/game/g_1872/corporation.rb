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

        def assign_branch_identity!(root, path, branch_city: nil)
          label = path.join('.')
          root_name = root.full_name || root.name
          root_sym = root.id
          branch_sym = root_sym ? "#{root_sym} #{label}" : "Branch #{label}"
          @id = branch_sym
          @sym = branch_sym
          @name = branch_sym

          if branch_city
            city_label = branch_city.to_s.strip
            self.full_name = "#{root_name} – #{city_label} Branch"
          else
            self.full_name = "#{root_name} – Branch #{label}"
          end
          assign_branch_logo!(root, path)
          self.color = root.color
          self.text_color = root.text_color
          @tokens = root.tokens
        end

        def token_proxy_corporation
          return nil unless type == :branch

          tokens.first&.corporation
        end

        private

        def assign_branch_logo!(root, _path)
          @logo_filename = root.logo_filename
          @logo = root.logo
          @simple_logo = root.simple_logo
        end
      end
    end
  end
end
