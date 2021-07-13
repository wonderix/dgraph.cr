require "http/client"
require "json"
require "uri"

# TODO: Write documentation for `Dgraph`
module Dgraph
  VERSION = "0.1.0"

  alias Types = String | Int32 | Time | Bool | Float64

  JSON_CONTENT_TYPE = HTTP::Headers.new.add("Content-Type", "application/json")
  DQL_CONTENT_TYPE  = HTTP::Headers.new.add("Content-Type", "application/json")

  struct QueryRequest
    include JSON::Serializable
    property query : String
    property variables : Hash(String, Types)?

    def initialize(@query : String, @variables = nil)
    end
  end

  struct QueryResponseData
    include JSON::Serializable
    property all : JSON::Any

    def initialize(@all : JSON::Any)
    end
  end

  struct QueryResponse
    include JSON::Serializable
    property data : QueryResponseData

    def initialize(@data : QueryResponseData)
    end
  end

  struct AlterRequest
    include JSON::Serializable
    property drop_attr : String?
    property drop_op : String?
    property drop_value : String?
    property drop_all : Bool?

    def initialize(@drop_all : Bool? = nil, @drop_attr : String? = nil, @drop_value : String? = nil, @drop_op : String? = nil)
    end
  end

  struct Error
    include JSON::Serializable
    property code : String?
    property message : String?

    def initialize(@code : String?, @message : String?)
    end
  end

  class Exception < ::Exception
    def initialize(errors : Array(Error))
      super(errors.map { |x| "code: #{x.code} message : #{x.message}" }.join(", "))
    end

    def initialize(message : String, errors : Array(Error))
      super("#{message} #{errors.map { |x| "code: #{x.code} message : #{x.message}" }.join(", ")}")
    end
  end

  struct ResponseData
    include JSON::Serializable
    property code : String?
    property message : String?
    property queries : JSON::Any?
    property uids : Hash(String, String)?
    property extensions : JSON::Any?

    def initialize(@code, @message, @queries, @uids, @extensions)
    end
  end

  struct Response
    include JSON::Serializable
    property errors : Array(Error)?
    property data : ResponseData?

    def initialize(@errors, @data)
    end

    def uids : Hash(String, String)
      data.try { |d| d.uids } || Hash(String, String).new
    end
  end

  class QueryIterator
    @stopped = false

    include Iterator(JSON::PullParser)

    def initialize(io : String)
      @pull = JSON::PullParser.new(io)
      @pull.read_begin_object
      until @pull.kind.end_object?
        key = @pull.read_object_key
        case key
        when "data"
          @pull.read_begin_object
          until @pull.kind.end_object?
            key = @pull.read_object_key
            @pull.read_begin_array
            break
          end
          break
        when "errors"
          errors = Array(Error).new(@pull)
          errors.try { |e| raise Exception.new(e) }
        else
          raise "Invalid member #{key}  at #{@pull.location}"
        end
      end
    end

    def next
      if @pull.kind.end_array?
        @pull.read_end_array
        @stopped = true
      end

      if @stopped
        stop
      else
        @pull
      end
    end

    def get(&block)
      v = self.next
      case v
      when Iterator::Stop
        nil
      else
        result = yield v
        raise "More than one object found" unless self.next == Iterator::Stop::INSTANCE
        result
      end
    end
  end

  class Client
    Log = ::Log.for(self)

    def initialize(url = "http://localhost:8080")
      uri = URI.parse(url)
      @client = HTTP::Client.new(uri.host || "localhost", uri.port || 8080)
    end

    def query(query, variables : Hash(String, Types) = nil) : QueryIterator
      Log.debug { query }
      response = @client.post("/query", JSON_CONTENT_TYPE, QueryRequest.new(query, variables).to_json)
      if response.status_code // 100 != 2
        raise response.body
      end
      Log.debug { JSON::Any.from_json(response.body).to_pretty_json }
      QueryIterator.new(response.body)
    end

    def self.handle_error(response)
      if response.status_code // 100 != 2
        raise response.body
      end
      resp = Response.from_json(response.body)
      resp.errors.try { |e| raise Exception.new(e) }
      nil
    end

    def alter(statement : String)
      Client.handle_error(@client.post("/alter", body: statement))
    end

    def alter(drop_all : Bool? = nil, drop_attr : String? = nil, drop_value : String? = nil, drop_op : String? = nil)
      req = AlterRequest.new(drop_all, drop_attr, drop_value, drop_op)
      Client.handle_error(@client.post("/alter", body: req.to_json))
    end

    def mutate(set = nil, delete = nil)
      o = IO::Memory.new
      builder = JSON::Builder.new(o)
      builder.document do
        builder.object do
          if set
            builder.field("set") do
              builder.array do
                set.each do |e|
                  e.to_json(builder)
                end
              end
            end
          end
          if delete
            builder.field("delete") do
              builder.array do
                delete.each do |e|
                  e.to_json(builder)
                end
              end
            end
          end
        end
      end
      Log.debug { o.to_s }
      response = @client.post("/mutate?commitNow=true", JSON_CONTENT_TYPE, body: o.to_s)
      if response.status_code / 100 != 2
        raise response.body
      end
      Log.debug { JSON::Any.from_json(response.body).to_pretty_json }
      resp = Response.from_json(response.body)
      resp.errors.try { |e| raise Exception.new(o.to_s, e) }
      resp
    end
  end
end
