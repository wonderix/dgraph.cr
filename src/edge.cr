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

  struct Edge(T, F)
    property value : T
    property facets : F

    def initialize(@value : T, @facets : F)
    end

    def self.of(o : Edge(T, F) | T)
      case o
      when T
        Edge.new(o, F.new)
      else
        o
      end
    end

    def initialize(name : String, pull : JSON::PullParser)
      name = name + "|"
      h = Hash(String, JSON::Any).new(pull)
      @value = T.from_json(Edge.create_json_object { |builder| h.each { |k, v| builder.field(k, v) unless k.starts_with?(name) } })
      @facets = F.from_json(Edge.create_json_object { |builder| h.each { |k, v| builder.field(k[name.size..-1], v) if k.starts_with?(name) } })
    end

    def self.create_json_object(&block) : IO::Memory
      io = IO::Memory.new
      builder = JSON::Builder.new(io)
      builder.document do
        builder.object do
          yield builder
        end
      end
      io.pos = 0
      io
    end

    def to_json(name : String, builder : JSON::Builder)
      builder.object do
        JSON.parse(@value.to_json).as_h.each do |key, value|
          builder.field(key, value)
        end
        name = name + "|"
        JSON.parse(@facets.to_json).as_h.each do |key, value|
          builder.field(name + key, value)
        end
      end
    end

    def self.dql_properties(io, depth, max_depth)
      F.dql_properties(io, depth, max_depth)
      T.dql_properties(io, depth, max_depth)
    end
  end
end
