# frozen_string_literal: true

module NomadEventStreamer
  class Event
    class Topic
      class << self
        def register(adapter, type)
          adapters[type] = adapter
        end

        def find(type)
          adapters[type]
        end

        def adapters
          @adapters ||= {}
        end
      end
    end
  end
end

require_relative "./topics/allocation"
require_relative "./topics/job"
