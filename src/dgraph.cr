require "./client"
require "./base"
require "./edge"
require "./facets"
require "pool/connection"

module Dgraph
  @@pool : ConnectionPool(Dgraph::Client)? = nil

  def self.setup(url = "http://localhost:8080", capacity = 25, timeout = 0.1)
    @@pool = ConnectionPool.new(capacity: capacity, timeout: timeout) do
      Dgraph::Client.new(url)
    end
  end

  def self.client : Dgraph::Client
    @@pool.not_nil!.connection
  end
end
