# frozen_string_literal: true

desc "Check modular-monolith dependency boundaries"
task "architecture:check" do
  checker = Rails.root.join("script", "check_architecture")
  abort "Architecture boundary check failed" unless system(checker.to_s)
end
