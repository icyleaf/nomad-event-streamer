# frozen_string_literal: true

require "http"

module NomadEventStreamer
  module Notification
    class Discord
      def initialize(webhook:)
        @webhook = webhook
      end

      def send(payload)
        HTTP.post(@webhook, json: payload)
      end

      Notification.register self, :discord
    end
  end
end
