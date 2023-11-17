# frozen_string_literal: true

module NomadEventStreamer
  class Event
    module Allocation
      def handle_allocation(event)
        latest_timestamp_cached = @cache.fetch_task(event.key, :latest_timestamp)
        latest_timestamp = nil

        event.task_states.each do |task|
          # Ignore connect proxies
          next if task.name.include?("connect-proxy")

          task_identifier = "#{event.job_id}.#{task.name}"

          if @config.task_denylist?(task_identifier)
            logger.warn "#{task_identifier} task skipped due to denylist"
            next
          end

          task.events.each do |task_event|
            if latest_timestamp.nil? || task_event.time > latest_timestamp
              latest_timestamp = task_event.time
            end

            if !latest_timestamp_cached.nil? && task_event.time <= latest_timestamp_cached
              logger.warn "#{task_identifier}: \"#{task_event.type}\" event skipped due to being older"
              next
            end

            if @config.task_event_denylist?(task_event.type)
              logger.warn "#{task_identifier}: \"#{task_event.type}\" event skipped due to denylist"
              next
            end

            if @config.task_event_allowlist?(task_event.type)
              logger.warn "#{task_identifier}: \"#{task_event.type}\" event skipped due to allowlist"
              next
            end

            send_notification(event, task, task_event)

            if latest_timestamp && (latest_timestamp_cached.nil? || latest_timestamp > latest_timestamp_cached)
              latest_timestamp_cached = latest_timestamp
              @cache.write_task(event.key, latest_timestamp: latest_timestamp_cached, expires_in: 1.day)
            end
          end
        end
      end

      private

      def send_notification(event, task, task_event)
        body = {
          "username": "Nomad event",
          "avatar_url": "https://icons-for-free.com/iconfiles/png/512/nomad-1331550891549310611.png",
          "embeds": [ build_embeds(event, task, task_event) ]
        }

        logger.debug "Prepare to enable notification"
        @config.notification.each do |type, options|
          logger.debug "detet #{type}"
          next unless NomadEventStreamer::Notification.exists?(type)

          logger.debug "Notification to send #{type}"
          NomadEventStreamer::Notification.send(type, body, **options)
        end
      end

      def build_embeds(event, task, task_event)
        embed = {
          title: "**#{event.job_id}**",
          description: task_event.display_message,
          url: "#{@config.nomad_addr}/ui/jobs/#{CGI.escape(event.job_id)}",
          color: embed_color(task_event),
          footer: {
            text: task.started_at ? "⌛️ Started at #{task.started_at}" : ""
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
              value: event.node_name,
              inline: true
            },
            {
              name: "Namespace",
              value: event.namespace,
              inline: true
            },
            {
              name: "Job",
              value: event.job_id
            },
            {
              name: "Task",
              value: event.task_group
            },
          ]
        }

        details = task_event.details
        unless details.empty?
          embed[:fields] << { name: "__`Detail`__", value: "" }
          task_event.details.each do |key, value|
            embed[:fields] << { name: key, value: value}
          end
        end

        embed
      end

      def embed_color(task_event)
        details = task_event.details
        state = case task_event.type
                when Topic::Allocation::Task::Event::Type::TaskRestartSignal
                  if details.dig("restart_reason")&.match?(/unhealthy/)
                    :failure
                  else
                    :success
                  end
                when Topic::Allocation::Task::Event::Type::TaskTerminated
                  if details.dig("oom_killed") == "true"
                    :failure
                  else
                    details.dig("exit_code") == "0" ? :success : :failure
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
    end
  end
end
