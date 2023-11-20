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

          notification_entry = Notification::Entry.new
          notification_entry.add_event(event, task)

          restart_signal = false
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

            restart_signal = true if task_event.type == Event::Type::TaskRestartSignal
            next if restart_signal && task_event.type == Event::Type::TaskTerminated

            notification_entry.append_task_event(task_event)

            if latest_timestamp && (latest_timestamp_cached.nil? || latest_timestamp > latest_timestamp_cached)
              latest_timestamp_cached = latest_timestamp
              @cache.write_task(event.key, latest_timestamp: latest_timestamp_cached, expires_in: 1.day)
            end
          end

          send_notification(:allocation, notification_entry) if notification_entry.any?
        end
      end
    end
  end
end
