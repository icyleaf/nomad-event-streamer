# frozen_string_literal: true

module NomadEventStreamer
  class Event
    # Event topic
    # Link: https://developer.hashicorp.com/nomad/api-docs/events#event-topics
    class Topic
      module Allocations
        AllocationCreated = "AllocationCreated"
        AllocationUpdated = "AllocationUpdated"
        AllocationUpdateDesiredStatus = "AllocationUpdateDesiredStatus"
      end

      class Base
        attr_reader :body

        def initialize(body)
          @body = body
        end

        def topic
          raise NotImplementedError
        end

        def type
          @type ||= @body["Type"]
        end

        def key
          @key ||= @body["Key"]
        end

        def namespace
          @namespace ||= @body["Namespace"]
        end

        def payload
          @payload ||= @body["Payload"]
        end
      end
    end
  end
end
