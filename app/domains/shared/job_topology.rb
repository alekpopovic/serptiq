# frozen_string_literal: true

module Shared
  module JobTopology
    QueueDefinition = Data.define(:name, :priority, :worker_role)
    WorkerDefinition = Data.define(:role, :queues, :default_threads, :maximum_threads, :dispatcher)

    QUEUES = {
      default: QueueDefinition.new(:default, 20, :worker_default),
      mail: QueueDefinition.new(:mail, 10, :worker_default),
      integrations: QueueDefinition.new(:integrations, 30, :worker_default),
      billing: QueueDefinition.new(:billing, 0, :worker_default),
      crawl: QueueDefinition.new(:crawl, 20, :worker_crawl),
      render: QueueDefinition.new(:render, 20, :worker_render),
      analysis: QueueDefinition.new(:analysis, 20, :worker_analysis),
      reports: QueueDefinition.new(:reports, 20, :worker_report),
      maintenance: QueueDefinition.new(:maintenance, 50, :worker_default)
    }.freeze

    WORKERS = {
      scheduler: WorkerDefinition.new(:scheduler, [].freeze, 0, 0, false),
      worker_default: WorkerDefinition.new(
        :worker_default,
        %i[billing mail default integrations maintenance].freeze,
        3,
        16,
        true
      ),
      worker_crawl: WorkerDefinition.new(:worker_crawl, %i[crawl].freeze, 3, 16, false),
      worker_render: WorkerDefinition.new(:worker_render, %i[render].freeze, 1, 1, false),
      worker_analysis: WorkerDefinition.new(:worker_analysis, %i[analysis].freeze, 2, 8, false),
      worker_report: WorkerDefinition.new(:worker_report, %i[reports].freeze, 2, 8, false)
    }.freeze

    module_function

    def queue(name)
      QUEUES.fetch(name.to_sym)
    rescue KeyError
      raise ArgumentError, "unknown job queue #{name.inspect}"
    end

    def worker(role)
      WORKERS.fetch(role.to_sym)
    rescue KeyError
      raise ArgumentError, "unknown job process role #{role.inspect}"
    end

    def route(job_class, queue_name)
      definition = queue(queue_name)
      job_class.queue_as(definition.name)
      job_class.queue_with_priority(definition.priority)
    end

    def execution_options(role, environment: ENV)
      definition = worker(role)
      return { threads: 0, processes: 0 } if definition.queues.empty?

      {
        threads: bounded_integer(
          environment.fetch("SEARCHOPS_JOB_THREADS", definition.default_threads),
          name: "SEARCHOPS_JOB_THREADS",
          range: 1..definition.maximum_threads
        ),
        processes: bounded_integer(
          environment.fetch("SEARCHOPS_JOB_PROCESSES", 1),
          name: "SEARCHOPS_JOB_PROCESSES",
          range: 1..16
        )
      }
    end

    def bounded_integer(raw_value, name:, range:)
      value = Integer(raw_value.to_s, 10)
      raise ArgumentError, "#{name} must be between #{range.begin} and #{range.end}" unless range.cover?(value)

      value
    rescue ArgumentError => error
      raise error if error.message.start_with?(name)

      raise ArgumentError, "#{name} must be an integer between #{range.begin} and #{range.end}"
    end
    private_class_method :bounded_integer
  end
end
