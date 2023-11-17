# frozen_string_literal: true

module NomadEventStreamer
  class Event
    def self.parse(raw, logger:)
      instance = new(logger)
      instance.parse(raw)
      instance
    end

    attr_reader :id, :events

    def initialize(logger)
      @logger = logger
    end

    def parse(raw)
      return if raw.empty?

      @id = parse_index(raw)
      @events = parse_events(raw)
    end

    def empty?
      @id.nil? || @events.nil?
    end

    private

    def parse_index(raw)
      raw["Index"]
    end

    def parse_events(raw)
      raw["Events"]&.each_with_object([]) do |event, obj|
        topic = event["Topic"]
        topic_class = Topic.find(topic)
        unless topic_class
          logger.debug "No registered event topic: #{topic}, skipped"
          next
        end

        obj << topic_class.new(event)
      end
    end

    def logger
      @logger
    end
  end
end

require_relative "./event/topic"
