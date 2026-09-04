module ApplicationHelper
  def display_price(cents, currency)
    number_to_currency(cents / 100.0, unit: currency, format: "%u %n", precision: 0)
  end

  def commercial_state_badge(state)
    case state.to_s
    when "enabled", "available", "unlimited" then "so-badge-success"
    when "disabled", "exhausted" then "so-badge-warning"
    else "so-badge-neutral"
    end
  end
end
