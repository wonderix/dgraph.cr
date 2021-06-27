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

  annotation Facet
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

      def self.insert(*args)
        self.new(*args).insert
      end
  
    end

    macro edge(decl, **options)
      {% type = decl.type %}

      {% reverse = !!options[:reverse] %}
      {% facets = (options[:facets] && !options[:facets].nil?) ? options[:facets] : nil %}
      {% name = (options[:name] && !options[:name].nil?) ? options[:name] : decl.var.id.stringify %}

      {% for facet in (facets || [] of Object ) %}
      {% raise "#{facet}: facets can only be of type Int32, Bool, String or Time" unless facet.type.id == Int32.id || facet.type.id == Bool.id || facet.type.id == String.id || facet.type.id == Time.id %}
      @[Dgraph::Facet()]
      @[JSON::Field("{{decl.var.id}}|" + {{facet.var.id}})]
      @{{decl.var.id}}_{{facet.var.id}} : {{facet.type.id}}? 

      def {{decl.var.id}}_{{facet.var.id}}=(@{{decl.var.id}}_{{facet.var.id}} : {{facet.type.id}}); end

      def {{decl.var.id}}_{{facet.var.id}} : {{facet.type.id}}
        @{{decl.var.id}}_{{facet.var.id}}.not_nil!
      end
      {% end %}


      @[Dgraph::Edge(name: {{name}}, reverse: {{reverse}}, facets: {{facets ? facets.map{|f| f.var.id} : nil}})]
      @{{decl.var}} : {{decl.type}}? {% unless decl.value.is_a? Nop %} = {{decl.value}} {% end %}

      def {{decl.var.id}}=(@{{decl.var.id}} : {{type.id}}); end

      def {{decl.var.id}} : {{type.id}}
        raise NilAssertionError.new {{@type.name.stringify}} + "#" + {{decl.var.stringify}} + " cannot be nil" if @{{decl.var}}.nil?
        @{{decl.var}}.not_nil!
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
            {% json = ivar.annotation(::JSON::Field) %}
            {% facet = ivar.annotation(Dgraph::Facet) %}
            {% unless (json && (json[:ignore] || json[:ignore_deserialize])) || facet %}
              io.print("  " * (depth + 1))
              {% name = ((json && json[:key]) || ivar).id %}
              {% edge = ivar.annotation(::Dgraph::Edge) %}
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
                {% if edge[:facets] %}
                  io.print(" @factets(" + {{edge[:facets].join(", ")}} +") ")
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
      io.puts("  " * depth + "}")  unless depth == 0
    end
  end
end
