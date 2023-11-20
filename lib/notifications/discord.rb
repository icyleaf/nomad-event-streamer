# frozen_string_literal: true

require "http"
require_relative "./base"

module NomadEventStreamer
  module Notification
    class Discord < Base
      DEFAULT_USERNAME = "Nomad event"
      DEFAULT_AVATAR_URL = "https://icons-for-free.com/iconfiles/png/512/nomad-1331550891549310611.png"

      def initialize(**options)
        @webhook = options.fetch(:webhook)
        @username = options.fetch(:username, DEFAULT_USERNAME)
        @avatar_url = options.fetch(:avatar_url, DEFAULT_AVATAR_URL)

        super
      end

      def send_allocation(entry)
        if entry.task_events.empty?
          logger.warn "Task event is empty!!!"
          return
        end

        payload = {
          "username": @username,
          "avatar_url": @avatar_url,
          "embeds": embeds(entry)
        }

        request_webhook(@webhook, payload)
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

      def embeds(entry)
        entry.task_events.each_with_object([]) do |task_event, obj|
          obj << single_embed(entry.event, task_event)
        end
      end

      def single_embed(event, task_event)
        embed = {
          title: "**#{event.job}**",
          description: task_event.display_message,
          url: "#{@config.nomad_addr}/ui/jobs/#{CGI.escape(event.job)}",
          color: embed_color(task_event),
          footer: {
            text: event.started_at ? "⌛️ Started at #{event.started_at}" : ""
          },
          author: {
            name: task_event.type
          },
          fields: [
            {
              name: "__`General`__",
              value: ""
            },
            {
              name: "Node",
              value: event.node,
              inline: true
            },
            {
              name: "Namespace",
              value: event.namespace,
              inline: true
            },
            {
              name: "Job",
              value: event.job
            },
            {
              name: "Task",
              value: event.task
            },
          ]
        }

        metadata = task_event.metadata
        unless metadata.empty?
          embed[:fields] << { name: "__`Detail`__", value: "" }
          metadata.each do |key, value|
            embed[:fields] << { name: key, value: value}
          end
        end

        embed
      end

      def embed_color(task_event)
        metadata = task_event.metadata
        state = case task_event.type
                when Event::Type::TaskRestartSignal
                  if metadata.dig("restart_reason")&.match?(/unhealthy/)
                    :failure
                  else
                    :success
                  end
                when Event::Type::TaskTerminated
                  if metadata.dig("oom_killed") == "true"
                    :failure
                  else
                    metadata.dig("exit_code") == "0" ? :success : :failure
                  end
                else
                  :normal
                end
        case state
        when :failure
          # Red
          15158332
        when :success
          # Green
          3066993
        when :normal
          # Orange
          15105570
        end
      end

      Notification.register self, :discord
    end
  end
end
