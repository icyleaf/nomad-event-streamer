# frozen_string_literal: true

module NomadEventStreamer
  module Notification
    class Base
      attr_accessor :cache, :config

      def initialize(**options)
        @cache = options.fetch(:cache)
        @config = options.fetch(:config)
      end

      def send(event)
        raise NotImplementedError
      end

      def request_webhook(webhook_url, payload)
        response = client.post(webhook_url, json: payload)
        unless response.status.success?
          message = "[#{self.class.name}] unexpected HTTP status #{response.code}: #{response.body}"
          logger.error message, status_code: response.code, body: response.body
        end
      rescue => e
        logger.error "[#{self.class.name}] unexpected HTTP error", exception: e
      end

      def client
        @client = HTTP
        @client = @client.use(logging: {logger: logger}) if @config.debug?
        @client
      end

      def logger
        @logger ||= @config.logger
      end
    end
  end
end
