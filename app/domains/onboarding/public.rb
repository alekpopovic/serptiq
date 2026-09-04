# frozen_string_literal: true

module Onboarding
  module Public
    module_function

    def start_draft(**attributes)
      StartDraft.new.call(**attributes)
    end

    def active_draft(**attributes)
      DraftDirectory.new.active(**attributes)
    end

    def draft(**attributes)
      DraftDirectory.new.find(**attributes)
    end

    def update_draft(**attributes)
      UpdateDraft.new.call(**attributes)
    end

    def cancel_draft(**attributes)
      CancelDraft.new.call(**attributes)
    end

    def complete_draft(**attributes)
      CompleteDraft.new.call(**attributes)
    end

    def plan_preview(**attributes)
      BuildPlanPreview.new.call(**attributes)
    end

    def readiness(**attributes)
      BuildReadiness.new.call(**attributes)
    end
  end
end
