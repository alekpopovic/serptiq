# frozen_string_literal: true

module Shared
  module DatabaseConnections
    class Primary < ActiveRecord::Base
      self.abstract_class = true
      connects_to database: { writing: :primary }
    end

    class Queue < ActiveRecord::Base
      self.abstract_class = true
      connects_to database: { writing: :queue }
    end

    class Cache < ActiveRecord::Base
      self.abstract_class = true
      connects_to database: { writing: :cache }
    end

    class Cable < ActiveRecord::Base
      self.abstract_class = true
      connects_to database: { writing: :cable }
    end

    CONNECTIONS = {
      primary: Primary,
      queue: Queue,
      cache: Cache,
      cable: Cable
    }.freeze

    def self.fetch(name)
      CONNECTIONS.fetch(name.to_sym)
    rescue KeyError
      raise ArgumentError, "unknown database connection #{name.inspect}"
    end
  end
end
