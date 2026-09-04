# frozen_string_literal: true

module Properties
  module PropertyConfiguration
    module_function

    def build(kind, attributes)
      values = attributes.to_h.symbolize_keys
      case kind.to_s
      when "website", "web_application"
        WebsiteConfiguration.new(origin: values[:origin])
      when "android_app"
        AndroidConfiguration.new(package_name: values[:package_name])
      when "ios_app"
        IosConfiguration.new(bundle_id: values[:bundle_id], team_id: values[:team_id])
      else
        raise ArgumentError, "property type is unsupported"
      end
    end
  end
end
