require "json"

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
    {% end %}
  end
end

struct Union(*T)
  def self.dql_properties(io, depth, max_depth)
    {% begin %}
      {{@type.union_types.reject { |x| x == Nil }[0].id}}.dql_properties(io, depth, max_depth)
    {% end %}
  end
end

module Dgraph
  annotation EdgeAnnotation
  end

  annotation Facet
  end

  module Base
    macro included
      include JSON::Serializable

      @[JSON::Field(key: "dgraph.type")]
      property _type = "{{@type.name.id}}"
      @uid : String?

      def uid : String
        @uid.not_nil!
      end

      def self.delete(objs)
        Dgraph.client.mutate(delete: objs.map{ | x | {"uid" => x.uid} }.to_a)
      end

      def self.all(depth = 1)
        Dgraph.client.query("{
              all(func: type(#{self.name})) #{self.dql_properties(depth)}
          }").map { |p| self.new(p) }
      end

      def self.get(uid , depth = 1)
        begin
          Dgraph.client.query("query get($uid: int) {
                all(func: uid($uid))  #{self.dql_properties(depth)}
            }", variables: {"$uid" => uid.to_s}).map { |p| self.new(p) }.first
        rescue e : JSON::SerializableError
          raise "#{self.name} for uid #{uid} not found"
        end
      end

      def self.dql_properties(io , depth, max_depth)
        instance = allocate   
        instance.dql_properties(io, depth, max_depth)
      end

      def self.insert(*args)
        self.new(*args).insert
      end
  
    end

    macro edge(decl, **options)
      {% type = decl.type %}

      {% reverse = !!options[:reverse] %}
      {% name = (options[:name] && !options[:name].nil?) ? options[:name] : decl.var.id.stringify %}

      {% if decl.var.ends_with?("s") %}
      @[Dgraph::EdgeAnnotation(name: {{name}}, reverse: {{reverse}})]
      @[JSON::Field(key: {{name}}, converter: Dgraph::NamedJsonArrayConverter({{type.id}}).new({{name}}))]
      @{{decl.var}} : Array({{type.id}})? = nil

      def {{decl.var.id}}=(@{{decl.var.id}} : Array({{type.id}}))
      end


      def {{decl.var.id}} : Array({{type.id}})
        raise NilAssertionError.new "Array({{type.id}}) #" + {{decl.var.stringify}} + " cannot be nil" if @{{decl.var}}.nil?
        @{{decl.var}}.not_nil!
      end
      {% else %}
      @[Dgraph::EdgeAnnotation(name: {{name}}, reverse: {{reverse}} )]
      @[JSON::Field(key: {{name}}, converter: Dgraph::NamedJsonConverter({{type.id}}).new({{name}}))]
      @{{decl.var}} : {{type}}? {% unless decl.value.is_a? Nop %} = {{decl.value}} {% end %}

      def {{decl.var.id}}=(@{{decl.var.id}} : {{type.id}});  end

      def {{decl.var.id}} : {{type.id}}
        raise NilAssertionError.new {{@type.name.stringify}} + "#" + {{decl.var.stringify}} + " cannot be nil" if @{{decl.var}}.nil?
        @{{decl.var}}.not_nil!
      end
      {% end %}
    end

    def insert
      @uid = "_:self" unless @uid
      resp = Dgraph.client.mutate(set: [self])
      @uid = resp.uids["self"] if @uid == "_:self"
      self
    end

    def delete
      Dgraph.client.mutate(delete: [{"uid" => @uid}])
    end

    def dql_properties(io, depth, max_depth)
      return if depth > max_depth
      io.print("{\n")
      {% begin %}
        {% for ivar in @type.instance_vars %}
          {% unless ivar.id.stringify == "_type" %}
            {% json = ivar.annotation(::JSON::Field) %}
            {% unless (json && (json[:ignore] || json[:ignore_deserialize])) %}
              io.print("  " * (depth + 1))
              {% name = ((json && json[:key]) || ivar).id %}
              {% edge = ivar.annotation(::Dgraph::EdgeAnnotation) %}
              {% if edge %}
                {% if edge[:reverse] %}
                  io.print(" {{name}} : ~" + {{edge[:name]}} )
                {% else %}
                  {% if name == edge[:name] %}
                  io.print(" {{name}} : " + {{edge[:name]}})
                  {% else %}
                    io.print(" {{name}}")
                  {% end %}
                {% end %}
              {% else %}
                io.print(" {{name}}")
              {% end %}
              {{ivar.type.id}}.dql_properties(io, depth+1, max_depth)
              io.puts("")
            {% end %}
          {% end %}
        {% end %}
      {% end %}
      io.puts("  " * depth + "}")
    end
  end
end
