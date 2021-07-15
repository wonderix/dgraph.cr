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

  def to_json(name : String, builder : JSON::Builder)
    builder.array do
      self.each { |e| e.to_json(name, builder) }
    end
  end

  def self.new(name : String, pull : JSON::PullParser)
    result = Array(T).new
    pull.read_array do
      result << T.new(name, pull)
    end
    result
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

  module Base
    macro included
      include JSON::Serializable

      @[JSON::Field(key: "dgraph.type")]
      property _type = "{{@type.name.id}}"
      @uid : String?

      def uid : String
        @uid ||  "_:nil"
      end

      def self.delete(objs)
        Dgraph.client.mutate(delete: objs.map{ | x | {"uid" => x.uid} }.to_a)
      end

      def self.all(depth = 1)
        Dgraph::Query(self).new(Dgraph.client).depth(depth).each
      end

      def self.where(**expressions)
        Dgraph::Query(self).new(Dgraph.client,expressions)
      end

      def self.get(uid , depth = 1)
        Dgraph::Query(self).new(Dgraph.client,uid: uid).depth(depth).get
      end

      def self.dql_properties(io , depth, max_depth)
        instance = allocate   
        instance.dql_properties(io, depth, max_depth)
      end

      def self.insert(*args,**kwargs)
        self.new(*args,**kwargs).save
      end
  
    end

    macro edge(decl, **options)
      {% type = decl.type %}
      {% raise "Edge type #{type} must be declared before (at least empty)" unless type.resolve? %}
      {% edge_type = type.resolve %}
      {% is_array = edge_type <= Array %}
      {% edge_type = edge_type.type_vars[0] if is_array %}
      {% converter_required = edge_type <= Dgraph::Edge %}
      {% reverse = !!options[:reverse] %}
      {% name = (options[:name] && !options[:name].nil?) ? options[:name] : decl.var.id.stringify %}

      @[Dgraph::EdgeAnnotation(reverse: {{reverse}} )]
      {% if converter_required %}
      @[JSON::Field(key: {{name}}, converter: Dgraph::EdgeJsonConverter({{type.id}}).new({{name}}), ignore_serialize: {{reverse}})]
      {% else %}
      @[JSON::Field(key: {{name}}, ignore_serialize: {{reverse}})]
      {% end %}
      @{{decl.var}} : {{type}}? {% unless decl.value.is_a? Nop %} = {{decl.value}} {% end %}

      def {{decl.var.id}}=(@{{decl.var.id}} : {{type.id}});  end

      def {{decl.var.id}} : {{type.id}}
        raise NilAssertionError.new {{@type.name.stringify}} + "#" + {{decl.var.stringify}} + " cannot be nil" if @{{decl.var}}.nil?
        @{{decl.var}}.not_nil!
      end
    end

    def save
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
              {% if edge && edge[:reverse] %}
                io.print(" {{name}} : ~{{name}}" )
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
