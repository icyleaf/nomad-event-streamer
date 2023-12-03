# frozen_string_literal: true

require_relative "./version"
require_relative "./config"
require_relative "./cache"
require_relative "./nomad"
require_relative "./event"
require_relative "./event/concerns/allocation"
require_relative "./notification"

module NomadEventStreamer
  class Runner
    include Event::Allocation

    def self.start
      new.start
    end

    def initialize
      Anyway::Settings.default_config_path = File.expand_path("../../config", __FILE__)

      @config = Config.new
      @cache = Cache.new(@config.cache_identifier, "cache", logger: @config.logger)
    end

    def start
      print_banner
      get_last_log_index
      watching_events
    rescue Interrupt => e
      logger.info "Exiting by Ctrl+C"
    end

    private

    def print_banner
      logger.info "Nomad Event Streamer is running ...", version: NomadEventStreamer::VERSION
    end

    def watching_events
      params = {
        namespace: @config.nomad["namespace"],
        topic: @config.nomad["event_topic"]
      }.compact

      body = client.streaming_events(params: params).body

      chunk_store = []
      loop do
        chunk = body.readpartial
        next if chunk == "\n"

        full_chunk = build_chunk(chunk, chunk_store)
        next unless full_chunk

        chunk_store.clear
        event_resource = parse_chunk(full_chunk)
        if !event_resource || event_resource.empty?
          logger.info "Empty event, heartbeat detected"
          next
        end

        event = Event.parse(event_resource, logger: @config.logger)
        next if previous_event?(event)

        handle_event(event)
      end
    rescue => exception
      logger.error "unexpected HTTP error", exception: exception
      retry
    end

    def build_chunk(chunk, target_store)
      chunk_parts = if target_store.empty?
        chunk
      else
        target_store << chunk
        target_store.join
      end

      if partial_json_data?(chunk_parts)
        logger.debug "Detect parts chunk of event struct json body, comboining chunks"
        target_store << chunk if target_store.empty?
        return false
      end

      chunk_parts
    end

    def partial_json_data?(chunk)
      JSON.parse(chunk)

      false
    rescue JSON::ParserError
      true
    end

    def handle_event(event)
      event.events.each do |event|
        method_name = "handle_#{event.topic}".to_sym
        next unless self.respond_to?(method_name)

        send(method_name, event)
      end
    end

    def send_notification(topic, entry)
      @config.notification.each do |type, options|
        next unless NomadEventStreamer::Notification.exists?(type)

        logger.debug "Notification to send #{type}"
        new_options = options.merge(
          cache: @cache,
          config: @config
        )
        NomadEventStreamer::Notification.send(type, topic, entry, **new_options)
      end
    end

    # def handle_job(event)

    # end

    # def handle_evaluation(event)

    # end

    def parse_chunk(chunk)
      logger.debug "Receving chunk of body", body: chunk
      JSON.parse(chunk)
    rescue JSON::ParserError
      false
    end

    # Ignore older events
    def previous_event?(event)
      events = event.events.map do |e|
        "#{e.topic}.#{e.type}.#{e.job_id}"
      end

      logger.info "Ignore older events", events: events.join(", ")
      @starting_index >= event.id
    end

    # Retrieve last index so we know which events are older
    def get_last_log_index
      body = client.agent_self.parse
      @starting_index = body.dig("stats", "raft", "last_log_index")&.to_i
      unless @starting_index
        logger.error "Unable to determine starting index, ensure NOMAD_ADDR is pointing to server and not client!"
        exit 1
      end
    end

    def client
      @client ||= Nomad.new(@config)
    end

    def logger
      @logger ||= @config.logger
    end
  end
end
