# frozen_string_literal: true

require "http"

module NomadEventStreamer
  class Nomad
    def initialize(config)
      @config = config

      @endpoint = config.nomad["addr"]
      @token = config.nomad["token"]
      @version = config.nomad["version"]
    end

    def agent_self
      connection.get(api("agent/self"))
    end

    def streaming_events(*params)
      connection.get(api("event/stream"), *params)
    end

    private

    def api(path)
      URI.join(@endpoint, "/#{@version}/", path)
    end

    def connection
      @connection ||= -> () {
        http = HTTP.headers(
          user_agent: "NomadEventStreamer/#{NomadEventStreamer::VERSION}",
          content_type: "application/json"
        ).accept(:json)

        http.auth("Bearer #{@token}") if @token
        http
      }.call
    end
  end
end
