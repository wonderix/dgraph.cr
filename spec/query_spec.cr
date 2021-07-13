require "./spec_helper"

struct Simple
  include Dgraph::Base
  property property1 : String

  def initialize(@property1)
  end
end

describe Dgraph::Query do
  client = Dgraph::Client.new

  it "create correct dql" do
    Dgraph::Query(Simple).new(client, property1: "xxx").dql.should eq "query get($v0 : string) {\n        all(func: type(Simple)) @filter( eq(property1,$v0))  {\n   uid\n   property1\n}\n\n      }"
    Dgraph::Query(Simple).new(client).and(uid: "1234").dql.should eq "query get($v0 : string) {\n        all(func: type(Simple)) @filter( uid($v0))  {\n   uid\n   property1\n}\n\n      }"
  end
end
