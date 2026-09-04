# frozen_string_literal: true

module Authorization
  class CatalogReport
    MARKS = { true => "yes", false => "-" }.freeze

    def initialize(catalog: Catalog.load)
      @catalog = catalog
    end

    def call
      headings = [ "Permission", "Scope", "Risk", *@catalog.roles.map(&:name) ]
      rows = @catalog.permissions.map do |permission|
        grants = @catalog.roles.map { |role| MARKS.fetch(role.permission_keys.include?(permission.key)) }
        [ permission.key, permission.scope, permission.risk_level, *grants ]
      end
      widths = headings.each_index.map do |index|
        ([ headings[index] ] + rows.map { |row| row[index] }).map(&:length).max
      end
      output = []
      output << "Authorization catalog schema #{@catalog.schema_version} sha256:#{@catalog.checksum}"
      output << format_row(headings, widths)
      output << widths.map { |width| "-" * width }.join("-+-")
      rows.each { |row| output << format_row(row, widths) }
      "#{output.join("\n")}\n"
    end

    private

    def format_row(values, widths)
      values.each_with_index.map { |value, index| value.ljust(widths[index]) }.join(" | ")
    end
  end
end
