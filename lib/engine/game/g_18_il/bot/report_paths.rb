# frozen_string_literal: true

require 'fileutils' unless RUBY_ENGINE == 'opal'

module Engine
  module Game
    module G18IL
      module Bot
        module ReportPaths
          SUBDIRECTORIES = {
            'batch' => 'batches',
            'tournament' => 'tournaments',
            'evolution' => 'evolutions',
            'replay' => 'replays',
          }.freeze

          def self.resolve(report_dir:, prefix:, text_path:, json_path:)
            return [text_path, json_path] unless report_dir

            raise ArgumentError, 'Specify report_dir or explicit report paths, not both' if text_path || json_path

            output_dir = subdirectory(report_dir, prefix)
            FileUtils.mkdir_p(output_dir)
            number = next_number(output_dir, prefix)
            base_path = File.join(output_dir, format('%<prefix>s_%<number>03d', prefix: prefix, number: number))
            ["#{base_path}.txt", "#{base_path}.json"]
          end

          def self.resolve_replay(output_dir)
            FileUtils.mkdir_p(output_dir)
            number = next_number(output_dir, 'replay')
            File.join(output_dir, format('replay_%03d.json', number))
          end

          def self.subdirectory(report_dir, prefix)
            File.join(report_dir, SUBDIRECTORIES.fetch(prefix, "#{prefix}s"))
          end

          def self.next_number(report_dir, prefix)
            pattern = /^#{Regexp.escape(prefix)}_(\d+)\.(?:txt|json)$/
            numbers = Dir.children(report_dir).filter_map do |filename|
              match = pattern.match(filename)
              match[1].to_i if match
            end
            numbers.max.to_i + 1
          end

          private_class_method :next_number, :subdirectory
        end
      end
    end
  end
end
