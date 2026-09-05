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
  end
end
