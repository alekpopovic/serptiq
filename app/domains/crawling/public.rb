# frozen_string_literal: true

module Crawling
  module Public
    module_function

    def policy(**attributes)
      PolicyReader.new.call(**attributes)
    end

    def configure_policy(**attributes)
      WritePolicy.new.call(**attributes, change_kind: "configured")
    end

    def reset_policy(**attributes)
      WritePolicy.new.call(**attributes, change_kind: "reset")
    end

    def snapshot_for_scan(**attributes)
      SnapshotPolicy.new.call(**attributes)
    end

    def compile_glob(value)
      GlobPattern.new(value: value)
    end

    def delete_for_lifecycle!(clock: -> { Time.current }, **attributes)
      DeleteForLifecycle.new(clock: clock).call(**attributes)
    end

    def signed_artifact_url(**attributes)
      SignArtifact.new.call(**attributes)
    end
  end
end
