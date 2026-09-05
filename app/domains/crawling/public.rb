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

    def create_scan(clock: -> { Time.current }, id_generator: nil, **attributes)
      options = { clock: clock }
      options[:id_generator] = id_generator if id_generator
      CreateScan.new(**options).call(**attributes)
    end

    def transition_scan(clock: -> { Time.current }, **attributes)
      TransitionScan.new(clock: clock).call(**attributes)
    end

    def request_scan_cancellation(clock: -> { Time.current }, **attributes)
      RequestScanCancellation.new(clock: clock).call(**attributes)
    end

    def record_scan_progress(clock: -> { Time.current }, **attributes)
      RecordScanProgress.new(clock: clock).call(**attributes)
    end

    def scan_page(**attributes)
      ScanDirectory.new.page(**attributes)
    end

    def scan_details(**attributes)
      ScanDirectory.new.find(**attributes)
    end

    def latest_scan_observation(**attributes)
      LatestScanObservation.new.call(**attributes)
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
