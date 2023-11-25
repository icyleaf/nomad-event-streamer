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
      TaskEvent = Struct.new(:type, :display_message, :metadata) do
        EXIT_CODE_REGEX = /Exit Code:\s+(?<code>\d+)/

        # https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html
        def exit_code
          matches = display_message.match?(EXIT_CODE_REGEX)
          return unless matches

          case matches[:code].to_i
          when 0
            :sucess_exit
          when 1
            :general_error
          when 2
            :misuse_of_shell_builtins
          when 126
            :command_cannot_execute
          when 127
            :command_not_found
          when 128
            :invalid_argument
          when 130
            :cancel_by_ctrl_c
          when 137
            :oom
          end
        end
      end
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
