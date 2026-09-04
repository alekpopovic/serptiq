# frozen_string_literal: true

require "active_record/connection_adapters/postgresql_adapter"

# Domain timestamps represent instants and the ERD specifies timestamptz. Rails
# still exposes these columns as :datetime while PostgreSQL retains the offset-
# aware storage semantics.
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz
