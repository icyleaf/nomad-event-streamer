# frozen_string_literal: true

require_relative "./base"

module NomadEventStreamer
  class Event
    class Topic
      class Job < Base
        def topic
          :job
        end

        Topic.register self, "Job"
      end
    end
  end
end
