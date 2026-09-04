# frozen_string_literal: true

module TestSupport
  module PlanCatalogHelpers
    def publish_catalog_version(plan_key:, version:, authorization:, effective_at: nil, path: nil)
      review = path ?
        Administration::Public.plan_catalog_review(path: path) :
        Administration::Public.plan_catalog_review
      difference = review.entry_for(plan_key: plan_key, version: version)
      attributes = {
        plan_key: plan_key,
        version: version,
        expected_previous_version: difference.expected_previous_version,
        catalog_checksum: difference.source_checksum,
        effective_at: effective_at,
        confirmation: difference.publication_confirmation,
        authorization: authorization
      }
      attributes[:path] = path if path
      Plans::Public.publish_version(**attributes)
    end

    def catalog_publish_request_params(plan_key:, version:, confirmation: nil, effective_at: nil)
      difference = Administration::Public.plan_catalog_review.entry_for(
        plan_key: plan_key,
        version: version
      )
      {
        expected_previous_version: difference.expected_previous_version,
        catalog_checksum: difference.source_checksum,
        effective_at: effective_at,
        confirmation: confirmation || difference.publication_confirmation
      }
    end
  end
end
