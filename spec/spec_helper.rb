# frozen_string_literal: true

module Snabberb
  class Component
    attr_accessor :node
    attr_reader :root

    def self.needs(key, **opts)
      class_needs[key] = opts
    end

    def self.class_needs
      @class_needs ||= superclass.respond_to?(:class_needs) ? superclass.class_needs.clone : {}
    end

    def initialize(root, needs = {})
      @root = root || self
      @store = root? ? {} : @root.store
      unused = needs.keys - class_needs.keys
      raise "Unused needs passed to component: #{unused}." unless unused.empty?

      init_needs(needs)
    end

    def root?
      self == @root
    end

    def class_needs
      self.class.class_needs
    end

    def stores?(key)
      class_needs.dig(key, :store)
    end

    def store(key = nil, value = nil, skip: false)
      return @store if key.nil?
      raise "Cannot store key '#{key}' since it is not a stored need of #{self.class}." unless stores?(key)

      @store[key] = value
      instance_variable_set("@#{key}", value)
      @root.instance_variable_set("@#{key}", value) if !root? && @root.stores?(key)
      update unless skip
    end

    def update; end

    private

    def init_needs(needs)
      class_needs.each do |key, opts|
        if @store.key?(key) && opts[:store]
          instance_variable_set("@#{key}", @store[key])
        elsif needs.key?(key)
          @store[key] = needs[key] if opts[:store] && !@store.key?(key)
          instance_variable_set("@#{key}", needs[key])
        elsif opts&.key?(:default)
          instance_variable_set("@#{key}", opts[:default])
        else
          raise "Needs '#{key}' required but not provided."
        end
      end
    end
  end

  class Layout < Component
    needs :application
    needs :attach_func
    needs :javascript_include_tags
  end
end

require_relative '../lib/engine'
require_relative 'fixture_cache'
require_relative 'matchers'

Engine::Logger.set_level(Logger::FATAL)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

FIXTURES_DIR = File.join(File.dirname(__FILE__), '..', 'public', 'fixtures')

def fixture_at_action(*args, **kwargs)
  FixtureCache.instance.fixture_at_action(*args, **kwargs)
end
