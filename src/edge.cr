require "json"

module Dgraph
  class EdgeJsonConverter(T)
    @name : String

    def initialize(@name)
    end

    def to_json(value : T, builder : JSON::Builder)
      value.to_json(@name, builder)
    end

    def from_json(pull : JSON::PullParser)
      T.new(@name, pull)
    end
  end

  abstract struct Edge(T)
    @node : T?

    def node : T
      raise NilAssertionError.new "Edge#node cannot be nil" if @node.nil?
      @node.not_nil!
    end

    macro inherited

      def self.new(name : String, pull : ::JSON::PullParser)
        instance = allocate
        instance.initialize(name, pull)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      def self.dql_properties(io , depth, max_depth)
        instance = allocate   
        instance.dql_properties(io, depth, max_depth)
      end
    end

    def initialize(@node)
    end

    def initialize(name : String, pull : JSON::PullParser)
      {% begin %}
      node = Hash(String, JSON::Any).new
      pull.read_object do |key|
        case key
        {% for ivar in @type.instance_vars %}
        {% if ivar.name != "node" %}
        when name + "|{{ivar.name}}"
          @{{ivar.name}} = {{ivar.type}}.new(pull)
        {% end %}   
        {% end %}   
        else
          node[key] = JSON::Any.new(pull)
        end  
      end
      @node = T.new(JSON::PullParser.new(node.to_json))
      {% end %}
    end

    def to_json(name : String, builder : JSON::Builder)
      builder.start_object
      JSON.parse(@node.to_json).as_h.each do |key, value|
        builder.field(key, value)
      end
      {% begin %}
      {% for ivar in @type.instance_vars %}
      {% if ivar.name != "node" %}
      builder.field(name + "|{{ivar.name}}",@{{ivar.name}})
      {% end %}
      {% end %}
      {% end %}
      builder.end_object
    end

    def dql_properties(io, depth, max_depth)
      {% begin %}
      {% facets = @type.instance_vars.map { |i| i.name }.reject { |n| n == "node" }.join(", ") %}
      io.print(" @facets(" + {{facets}} + ")")
      {% end %}
      T.dql_properties(io, depth, max_depth)
    end

    macro facet(decl, **options)
      {% type = decl.type %}
      {% t = type.resolve %}
      {% raise "#{decl}: facets can only be of type Int32, Bool, String, Time or Enum" unless t <= Int32 || t <= Bool || t <= String || t <= Time || t < Enum %}
      @{{decl.var}} : {{type}}? {% unless decl.value.is_a? Nop %} = {{decl.value}} {% end %}

      def {{decl.var.id}}=(@{{decl.var.id}} : {{type.id}});  end

      def {{decl.var.id}} : {{type.id}}
        raise NilAssertionError.new {{@type.name.stringify}} + "#" + {{decl.var.stringify}} + " cannot be nil" if @{{decl.var}}.nil?
        @{{decl.var}}.not_nil!
      end
    end
  end
end
