# frozen_string_literal: true

require "active_support/deprecation"
require "active_support/cache"
require "forwardable"

module NomadEventStreamer
  class Cache
    extend Forwardable

    ALLOWED_KEYS = %i[starting_index]

    def_delegators :@store, :read, :write, :delete, :clear

    def initialize(identifier, path, logger: nil)
      ActiveSupport::Cache.format_version = 7.0

      @store = ActiveSupport::Cache::FileStore.new(File.join(path, identifier))
      @store.logger = logger if logger
      configure!
    end

    # Task methods
    def write_task(identifier, **params)
      cache_key = task_identifier(identifier)
      value = fetch(cache_key, {})
      new_value = value.merge(params)

      write(cache_key, new_value, **params)
    end

    def fetch_task(identifier, key, **default_value)
      cache_key = task_identifier(identifier)
      fetch(cache_key, default_value)[key]
    end

    def task_identifier(identifier)
      "task_#{identifier}"
    end

    # General methods

    def fetch(key, default_value)
      @store.fetch(key, force: false, expires_in: 1.day) { default_value }
    end

    def [](key)
      @store.read(key)
    end

    def []=(key, value, **options)
      @store.write(key, value, **options)
    end

    def method_missing(method_name, *kwargs)
      allowed, key, write_mode = allowed_key?(method_name)
      super unless allowed

      write_mode ? @store.write(key, kwargs.first) : @store.read(key)
    end

    def respond_to_missing?(method_name, include_private = false)
      allowed, _ = allowed_key?(method_name)
      allowed || super
    end

    def configure!
      ALLOWED_KEYS.each do |key|
        # @cache.exist?(key) ? @cache.read(key) :
        @store.fetch(key, nil)
      end
    end

    private

    def allowed_key?(key)
      key = key.to_s
      write_mode = key.end_with?("=")
      key = key[0..-2] if write_mode
      key = key.to_sym
      [ALLOWED_KEYS.include?(key), key, write_mode]
    end
  end
end
