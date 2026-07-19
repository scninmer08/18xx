# frozen_string_literal: true

require 'fileutils'

OUTPUT_DIR = File.expand_path('../public/logos/1872/shells', __dir__)
SHELL_COUNT = 24
FAMILIES = {
  'CNW' => ['#E2E071', '#000'],
  'CBQ' => ['#8C8C7E', '#000'],
  'MP' => ['#c62024', '#fff'],
  'UP' => ['#006D9C', '#fff'],
  'KP' => ['#93bcdc', '#000'],
  'KATY' => ['#006521', '#fff'],
  'RI' => ['#881319', '#fff'],
  'ATSF' => ['#000e4b', '#fff'],
}.freeze

def logo(label, color, text_color = '#fff')
  font_size = label.length > 2 ? 2.5 : 4
  <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 8 8">
      <circle cx="4" cy="4" r="3.85" fill="#{color}" stroke="#fff" stroke-width="0.3"/>
      <text x="4" y="5.35" text-anchor="middle" font-family="Arial, sans-serif" font-size="#{font_size}" font-weight="700" fill="#{text_color}">#{label}</text>
    </svg>
  SVG
end

FileUtils.mkdir_p(OUTPUT_DIR)

(1..SHELL_COUNT).each do |number|
  File.write(File.join(OUTPUT_DIR, format('S%02d.svg', number)), logo(format('S%02d', number), '#000'))
end

FAMILIES.each do |family, (color, text_color)|
  (1..SHELL_COUNT).each do |number|
    File.write(File.join(OUTPUT_DIR, "#{family}-#{number}.svg"), logo(number.to_s, color, text_color))
  end
end
