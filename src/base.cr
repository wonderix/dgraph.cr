module Dgraph
  module Base
    macro included
      include JSON::Serializable

      @[JSON::Field(key: "dgraph.type")]
      property _type = "{{@type.name.id}}"
      property uid : String?

      def self.dql_properties(io = IO::Memory.new)
        instance = allocate   
        instance.dql_properties(io)
        io.to_s
      end

      def self.delete(objs)
        Dgraph.client.mutate(delete: objs.map{ | x | {"uid" => x.uid} }.to_a)
      end
    end

    def insert
      self.uid = "_:self" unless self.uid
      resp = Dgraph.client.mutate(set: [self])
      self.uid = resp.uids["self"] if self.uid == "_:self"
      self
    end

    def delete
      Dgraph.client.mutate(delete: [{"uid" => self.uid}])
    end

    def dql_properties(io)
      {% begin %}
        {% for ivar in @type.instance_vars %}
          {% unless ivar.id.stringify == "_type" %}
            {% ann = ivar.annotation(::JSON::Field) %}
            {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
              {% if ivar.type < Dgraph::Base %}
                io.puts({{((ann && ann[:key]) || ivar).id.stringify}} + " {")
                {{ivar.type.id}}.dql_properties(io)
                io.puts("}")
              {% elsif ivar.type.union? %}
                {% for t in ivar.type.union_types %}
                  {% if t == Nil %}
                  {% elsif t < Dgraph::Base %}
                    io.puts({{((ann && ann[:key]) || ivar).id.stringify}} + " {")
                    {{t.id}}.dql_properties(io)
                    io.puts("}")
                  {% else %}
                    io.puts({{((ann && ann[:key]) || ivar).id.stringify}})
                  {% end %}
                {% end %}
              {% else %}
                io.puts({{((ann && ann[:key]) || ivar).id.stringify}})
              {% end %}
            {% end %}
          {% end %}
        {% end %}
      {% end %}
    end
  end
end
