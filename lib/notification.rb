# frozen_string_literal: true

module NomadEventStreamer
  module Notification
    class Entry
      attr_reader :event, :task_events

      def initialize
        @task_events ||= []
      end

      def empty?
        task_events.empty?
      end

      def any?
        !empty?
      end

      def add_event(event, task)
        @event = Event.new(
          event.job_id, event.alloc_id, event.namespace, event.node_name, event.task_group, task.started_at, task.finished_at
        )
      end

      def append_task_event(task_event)
        @task_events << TaskEvent.new(
          task_event.type, task_event.display_message, task_event.details
        )
      end

      Event = Struct.new(:job, :allocation_id, :namespace, :node, :task, :started_at, :finished_at)
      TaskEvent = Struct.new(:type, :display_message, :metadata)
    end

    class << self
      def register(klass, type)
        adapters[type.to_sym] = klass
      end

      def send(type, topic, event, **options)
        adapter = type.to_sym
        raise "Unknown adapter: #{adapter}" unless adapters.key?(adapter)

        new_options = options.transform_keys(&:to_sym)
        adapters[adapter].new(**new_options).send(topic.to_sym, event)
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
