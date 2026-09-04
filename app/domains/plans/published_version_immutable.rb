# frozen_string_literal: true

module Plans
  class PublishedVersionImmutable < Shared::Public::ConflictError
    def initialize(reason_code: "published_plan_version_immutable")
      super
    end
  end
end
