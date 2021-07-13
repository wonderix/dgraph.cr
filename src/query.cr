require "./client"

module Dgraph
  struct BinaryExpression
    property join : Symbol
    property field : String
    property operator : Symbol
    property variable : String

    def initialize(@join, @field, @operator, @variable)
    end

    def dql
      "#{@operator}(#{@field},#{@variable})"
    end
  end

  struct UidExpression
    property join : Symbol
    property variable : String

    def initialize(@join, @variable)
    end

    def dql
      "uid(#{@variable})"
    end
  end

  struct Query(T)
    @variables = Hash(String, Types).new
    @expressions = Array(BinaryExpression | UidExpression).new
    @client : Dgraph::Client
    @depth = 1

    def initialize(@client, expressions)
      add(:and, expressions)
    end

    def initialize(@client, **expressions)
      add(:and, expressions)
    end

    def depth(v : Int32)
      @depth = v
      self
    end

    def and(field : (Symbol | String), operator : Symbol, value : Types)
      add(join: :and, field: field.to_s, operator: operator, value: value)
    end

    def and(**expressions)
      add(:and, expressions)
    end

    # def and(expressions)
    #  add(:and, expressions)
    # end

    def or(**expressions)
      or(expressions)
    end

    def or(expressions)
      add(:or, expressions)
    end

    def or(field : (Symbol | String), operator : Symbol, value : Types)
      add(:or, field.to_s, operator, value)
    end

    private def add(join : Symbol, expressions)
      expressions.each do |field, value|
        add(join, field, :eq, value)
      end
      self
    end

    private def add(join : Symbol, field : (Symbol | String), operator : Symbol, value : Types)
      variable = "$v#{@variables.size}"
      if field.to_s == "uid"
        @expressions << UidExpression.new(join, variable)
      else
        @expressions << BinaryExpression.new(join, field.to_s, operator, variable)
      end
      @variables[variable] = value
      self
    end

    def dql
      decl = @variables.map do |k, v|
        case v
        when Int32
          "#{k} : int"
        when String
          "#{k} : string"
        when Time
          "#{k} : dateTime"
        when Bool
          "#{k} : bool"
        when Float64
          "#{k} : float"
        end
      end.join(", ")

      cond = @expressions.map_with_index do |e, i|
        "#{i == 0 ? "" : e.join.to_s} #{e.dql}"
      end.join(" ")
      "query get(#{decl}) {
        all(func: type(#{T.name})) @filter(#{cond})  #{T.dql_properties(@depth)}
      }"
    end

    def each : Iterator(T)
      @client.query(dql, @variables).map { |p| T.new(p) }
    end

    def get? : T?
      @client.query(dql, @variables).get { |p| T.new(p) }
    end

    def get : T
      get?.not_nil!
    end
  end
end
