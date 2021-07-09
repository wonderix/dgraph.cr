require "json"

module Dgraph
  module Facets
    macro included
      include JSON::Serializable

      def self.dql_properties(io , depth, max_depth)
        instance = allocate   
        instance.dql_properties(io, depth, max_depth)
      end
    end

    def dql_properties(io, depth, max_depth)
      {% begin %}
      {% facets = @type.instance_vars.map { |i| i.name }.join(", ") %}
      io.print(" @facets(" + {{facets}} + ")")
      {% end %}
    end
  end
end
