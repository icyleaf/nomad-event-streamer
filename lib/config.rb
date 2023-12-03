# frozen_string_literal: true

require "active_support"
require "semantic_logger"
require "anyway_config"
require "digest"

module NomadEventStreamer
  class Config < Anyway::Config
    config_name :config

    # Keep it, or it will be this module name by default
    env_prefix ""

    attr_config(
      nomad: {
        addr: "http://127.0.0.1:4646",
        version: "v1",
        token: nil,
        namespace: "*",
        event_topic: [
          "Allocation"
        ],
        denylist: {
          task: [],
          event_type: []
        },
        allowlist:{
          event_type: []
        }
      },

      # nomad_token: nil,
      # nomad_addr: ,
      # nomad_version: "v1",
      # nomad_namespace: "*",
      # nomad_event_topic: ["Allocation"],

      # nomad_task_denylist: [],
      # nomad_event_type_denylist: [],
      # nomad_event_type_allowlist: [],

      notification: {},

      timezone: "Asia/Shanghai",
      log: {
        level: "info",
        formatter: "default"
      },

      # development relates
      debug: {
        enable: false,
        proxy: {
          uri: "http://127.0.0.1:9091",
          username: nil,
          password: nil
        }
      }
    )

    # coerce_types nomad_task_denylist: {type: :string, array: true}
    # coerce_types nomad_event_type_denylist: {type: :string, array: true}
    # coerce_types nomad_event_type_allowlist: {type: :string, array: true}

    # required :nomad[:addr], :nomad[:version]

    on_load :ensure_nomad_settings
    on_load :ensure_notification

    def task_denylist?(key)
      nomad_task_denylist.any? { |q| key.include?(q) }
    end

    def task_event_denylist?(key)
      nomad_event_type_denylist.any? { |q| key.include?(q) }
    end

    def task_event_allowlist?(key)
      nomad_event_type_allowlist.any? { |q| key.include?(q) }
    end

    def cache_identifier
      Digest::SHA256.hexdigest(nomad["addr"])[0..8]
    end

    def debug?
      Anyway::Settings.current_environment = "development" || !!debug
    end

    def logger
      @logger ||= -> {
        SemanticLogger.default_level = debug? ? "trace" : log.fetch("level", "info")
        SemanticLogger.add_appender(io: STDOUT, formatter: log.fetch("formatter", "default").to_sym)
        SemanticLogger["NomadEventStreamer"]
      }.call
    end

    # def nomad
    #   Nomad.new(

    #   )
    # end

    private

    def ensure_notification
      raise_validation_error "Notification is missing" if notification.blank?
    end

    NOMAD_REQUIRES_KEYS = %w[addr version]
    def ensure_nomad_settings
      NOMAD_REQUIRES_KEYS.each do |key|
        raise_validation_error "Missing key `#{key}` in nomad setting" if nomad[key].blank?
      end
    end

    Nomad = Struct.new(:addr, :version, :token, :namespace, :event_type, :denylist, :allowlist)
  end
end
