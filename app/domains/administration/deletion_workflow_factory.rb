# frozen_string_literal: true

module Administration
  module DeletionWorkflowFactory
    module_function

    def executor
      ExecuteDeletionWorkflow.new(stage_runner: DeletionStageRunner.new(object_store: object_store))
    end

    def object_store
      Crawling::Public.artifact_store
    end
  end
end
