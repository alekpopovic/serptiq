# frozen_string_literal: true

class AddLemonSqueezyMappingCoordinates < ActiveRecord::Migration[8.1]
  def change
    add_column :billing_plan_provider_mappings, :provider_store_id, :string, limit: 128
    add_column :billing_plan_provider_mappings, :provider_product_id, :string, limit: 128

    add_check_constraint :billing_plan_provider_mappings,
      "(provider_store_id IS NULL AND provider_product_id IS NULL) OR " \
      "(provider_store_id IS NOT NULL AND provider_product_id IS NOT NULL)",
      name: "billing_plan_mappings_catalog_coordinates_shape"
    add_check_constraint :billing_plan_provider_mappings,
      "provider <> 'lemon_squeezy' OR " \
      "(provider_store_id IS NOT NULL AND provider_product_id IS NOT NULL AND " \
      "provider_store_id ~ '^[1-9][0-9]{0,18}$' AND " \
      "provider_product_id ~ '^[1-9][0-9]{0,18}$' AND " \
      "provider_variant_id ~ '^[1-9][0-9]{0,18}$')",
      name: "billing_plan_mappings_lemon_squeezy_coordinates"
    add_index :billing_plan_provider_mappings,
      %i[provider environment provider_store_id provider_product_id provider_variant_id],
      unique: true,
      where: "provider_store_id IS NOT NULL AND provider_product_id IS NOT NULL",
      name: "index_billing_plan_mappings_on_provider_catalog_identity"
  end
end
