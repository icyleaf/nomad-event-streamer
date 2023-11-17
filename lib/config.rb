# frozen_string_literal: true

require "anyway_config"
require "digest"
require "logger"

module NomadEventStreamer
  class Config < Anyway::Config
    config_name :config

    # Keep it, or it will be this module name by default
    env_prefix ""

    attr_config(
      nomad_token: nil,
      nomad_addr: "http://127.0.0.1:4646",
      nomad_version: "v1",
      nomad_namespace: "*",
      nomad_event_topic: ["Allocation"],

      nomad_task_denylist: [],
      nomad_event_type_denylist: [],
      nomad_event_type_allowlist: [],

      timezone: "Asia/Shanghai",
      notification: {},

      # development relates
      debug: false,
      proxy: {
        uri: "http://127.0.0.1:9091",
        username: nil,
        password: nil
      }
    )

    coerce_types nomad_task_denylist: {type: :string, array: true}
    coerce_types nomad_event_type_denylist: {type: :string, array: true}
    coerce_types nomad_event_type_allowlist: {type: :string, array: true}

    required :nomad_addr, :nomad_version

    on_load :ensure_notification_is_vaild

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
      Digest::SHA256.hexdigest(nomad_addr)[0..8]
    end

    def debug?
      !!debug
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    private

    def ensure_notification_is_vaild
      raise_validation_error "Notification is missing" if notification.empty?
    end
  end
end
