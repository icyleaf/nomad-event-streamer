# frozen_string_literal: true

require_relative "./version"
require_relative "./notification"
require_relative "./config"
require_relative "./cache"
require_relative "./nomad"
require_relative "./event"

require_relative "./event/concerns/allocation"

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
    end

    private

    def print_banner
      logger.info "Nomad Event Streamer v#{NomadEventStreamer::VERSION} is running ..."
    end

    def watching_events
      params = {
        namespace: @config.nomad_namespace,
        topic: @config.nomad_event_topic
      }.compact

      body = client.streaming_events(params: params).body

      chunk_store = []
      loop do
        chunk = body.readpartial
        next if chunk == "\n"

        full_chunk = build_chunk(chunk, chunk_store)
        next unless full_chunk

        # binding.break

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

        logger.debug "Go to ##{method_name} method"
        send(method_name, event)
      end
    end

    # def handle_job(event)

    # end

    # def handle_evaluation(event)

    # end

    def parse_chunk(chunk)
      logger.debug "event_stream_body: `#{chunk}`"
      JSON.parse(chunk)
    rescue JSON::ParserError
      false
    end

    # Ignore older events
    def previous_event?(event)
      logger.info "Ignore older events"
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
