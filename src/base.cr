class Object
  def self.dql_properties(io, depth, max_depth)
    # raise "Test"
  end

  def self.dql_properties(max_depth = 1)
    io = IO::Memory.new  
    self.dql_properties(io, 0, max_depth)
    io.to_s
  end
end

class Array(T)
  def self.dql_properties(io, depth, max_depth)
    {% begin %}
      {{@type.type_vars[0]}}.dql_properties(io, depth, max_depth)
    {% end   %}
  end
end

struct Union(*T)
  def self.dql_properties(io, depth, max_depth)
    {% begin %}
      {{@type.union_types.reject{ | x | x == Nil}[0].id}}.dql_properties(io, depth, max_depth)
    {% end %}
  end
end

module Dgraph
  annotation Edge
  end

  module Base
    macro included
      include JSON::Serializable

      @[JSON::Field(key: "dgraph.type")]
      property _type = "{{@type.name.id}}"
      property uid : String?

      def self.delete(objs)
        Dgraph.client.mutate(delete: objs.map{ | x | {"uid" => x.uid} }.to_a)
      end

      def self.all
        Dgraph.client.query("{
              all(func: type(#{self.name})){
                #{self.dql_properties}
              }
          }").map { |p| self.new(p) }
      end

      def self.dql_properties(io , depth, max_depth)
        instance = allocate   
        instance.dql_properties(io, depth, max_depth)
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

    def dql_properties(io,depth, max_depth)
      return if depth > max_depth
      io.print("{\n") unless depth == 0
      {% begin %}
        {% for ivar in @type.instance_vars %}
          {% unless ivar.id.stringify == "_type" %}
            {% ann = ivar.annotation(::JSON::Field) %}
            {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
              io.print("  " * (depth + 1))
              io.print({{((ann && ann[:key]) || ivar).id.stringify}})
              {% ann = ivar.annotation(::Dgraph::Edge) %}
              {% if ann && ann[:reverse] %}
                io.print(" : ~" + {{ann[:reverse]}} + " ")
              {% end %}
              {{ivar.type.id}}.dql_properties(io, depth+1, max_depth)
              io.puts("")
            {% end %}
          {% end %}
        {% end %}
      {% end %}
      io.puts("  " * depth + "}")  unless depth == 0
    end
  end
end
