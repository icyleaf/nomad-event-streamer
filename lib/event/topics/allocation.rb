# frozen_string_literal: true

require_relative "./base"

module NomadEventStreamer
  class Event
    class Topic
      class Allocation < Base
        def topic
          :allocation
        end

        def alloc_id
          @alloc_id ||= allocation["ID"]
        end

        def job_id
          @job_id ||= allocation["JobID"]
        end

        def node_name
          @node_name ||= allocation["NodeName"]
        end

        def task_group
          @task_group ||= allocation["TaskGroup"]
        end

        def task_states
          @task_states ||= (allocation["TaskStates"] || {}).each_with_object([]) do |(name, resource), obj|
            obj << Task.parse(name, resource)
          end
        end

        def allocation
          @allocation ||= payload["Allocation"]
        end

        def resources
          @resources ||= Resources.parse(payload["Resources"])
        end

        Topic.register self, "Allocation"

        private

        class Resources
          def self.parse(body)
            instance = new
            instance.parse(body)
            instance
          end

          attr_reader :cpu, :memory, :max_memory, :disk
          def parse(body)
            @cpu = body["CPU"]
            @memory = body["MemoryMB"]
            @max_memory = body["MemoryMaxMB"]
            @disk = body["DiskMB"]
          end
        end

        class Task
          def self.parse(name, body)
            instance = new
            instance.parse(name, body)
            instance
          end

          attr_reader :name, :state, :failed, :restarts, :last_restart, :started_at, :finished_at, :events

          def parse(name, body)
            @name = name
            @state = body["State"]
            @failed = body["Failed"]
            @restarts = body["Restarts"]
            @last_restart = body["LastRestart"]
            @started_at = Time.parse(body["StartedAt"]) if body["StartedAt"]
            @finished_at = Time.parse(body["FinishedAt"]) if body["FinishedAt"]

            @events = parse_events(body)
          end

          private

          def parse_events(body)
            body["Events"].each_with_object([]) do |resource, obj|
              obj << Event.parse(resource)
            end
          end

          class Event
            module Type
              TaskSetup                  = "Task Setup"
              TaskSetupFailure           = "Setup Failure"
              TaskDriverFailure          = "Driver Failure"
              TaskDriverMessage          = "Driver"
              TaskReceived               = "Received"
              TaskFailedValidation       = "Failed Validation"
              TaskStarted                = "Started"
              TaskTerminated             = "Terminated"
              TaskKilling                = "Killing"
              TaskKilled                 = "Killed"
              TaskRestarting             = "Restarting"
              TaskNotRestarting          = "Not Restarting"
              TaskDownloadingArtifacts   = "Downloading Artifacts"
              TaskArtifactDownloadFailed = "Failed Artifact Download"
              TaskSiblingFailed          = "Sibling Task Failed"
              TaskSignaling              = "Signaling"
              TaskRestartSignal          = "Restart Signaled"
              TaskLeaderDead             = "Leader Task Dead"
              TaskBuildingTaskDir        = "Building Task Directory"
              TaskClientReconnected      = "Reconnected"
            end

            attr_reader :type, :time, :display_message, :details

            def self.parse(body)
              instance = new
              instance.parse(body)
              instance
            end

            def parse(body)
              @type = body["Type"]
              @time = body["Time"]
              @display_message = body["DisplayMessage"]
              @details = body["Details"]
            end
          end
        end
      end
    end
  end
end
