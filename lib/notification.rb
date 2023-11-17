# frozen_string_literal: true

module NomadEventStreamer
  module Notification
    class << self
      def register(klass, type)
        adapters[type.to_sym] = klass
      end

      def send(type, payload, **options)
        raise "Unknown adapter: #{type}" unless adapters.key?(type.to_sym)

        new_options = options.transform_keys(&:to_sym)
        adapters[type.to_sym].new(**new_options).send(payload)
      end

      def exists?(type)
        adapters.key?(type.to_sym)
      end

      def adapters
        @adapters ||= {}
      end
    end
  end
end


require_relative "./notifications/discord"
require_relative "./notifications/slack"
