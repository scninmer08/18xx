# frozen_string_literal: true

# backtick_javascript: true

module Lib
  module Storage
    def self.[](key)
      return unless RUBY_ENGINE == 'opal'

      value = `localStorage.getItem(#{key})`
      JSON.parse(value) if value && !value.empty?
    end

    def self.[]=(key, value)
      return value unless RUBY_ENGINE == 'opal'

      `localStorage.setItem(#{key}, #{JSON.dump(value)})`
      self[key]
    end

    def self.delete(key)
      return unless RUBY_ENGINE == 'opal'

      `localStorage.removeItem(#{key})`
    end

    def self.all_keys
      return [] unless RUBY_ENGINE == 'opal'

      `Object.keys(localStorage)`
    end
  end
end
