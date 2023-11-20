# frozen_string_literal: true

require "http"
require_relative "./base"

module NomadEventStreamer
  module Notification
    class Slack < Base
      DEFAULT_USERNAME = "Nomad event"
      DEFAULT_ICON_URL = "https://icons-for-free.com/iconfiles/png/512/nomad-1331550891549310611.png"

      def initialize(**options)
        @webhook = options.fetch(:webhook)
        @username = options.fetch(:username, DEFAULT_USERNAME)
        @icon_url = options.fetch(:avatar_url, DEFAULT_ICON_URL)
        @channel = options.fetch(:channel, nil)

        super
      end

      def send_allocation(entry)
        entry.task_events.each do |task_event|
          payload = playload(entry.event, task_event)
          request_webhook(@webhook, payload)
        end
      end

      def send(topic, entry)
        case topic
        when :allocation
          send_allocation(entry)
        else
          raise "Unknown topic: #{topic}"
        end
      end

      private

      def playload(event, task_event)
        payload = {
          "username": @username,
          "icon_url": @icon_url,
          "blocks": single_block(event, task_event)
        }
        payload[:channel] = @channel if @channel
        payload
      end

      def single_block(event, task_event)
        data = [
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*#{task_event.type}*\n<#{@config.nomad_addr}/ui/jobs/#{CGI.escape(event.job)}|#{event.job}> \n #{task_event.display_message}"
            }
          },
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "`General`"
            },
            fields: [
              {
                type: "mrkdwn",
                text: "*Node*\n#{event.node}"
              },
              {
                type: "mrkdwn",
                text: "*Namespace*\n#{event.namespace}"
              },
              {
                type: "mrkdwn",
                text: "*Job*\n#{event.job}"
              },
              {
                type: "mrkdwn",
                text: "*Task*\n#{event.task}"
              }
            ]
          }
        ]

        metadata = task_event.metadata
        unless metadata.empty?
          metadata_block = {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "`Detail`"
            },
            fields: []
          }
          metadata.each do |key, value|
            metadata_block[:fields] << { name: key, value: value}
          end

          data << metadata_block
        end

        data
      end

      Notification.register self, :slack
    end
  end
end
