require "./spec_helper"

struct Post
  include Dgraph::Base
  property message : String
  edge user : User
  def initialize(@message)
  end
end

struct User
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  edge posts : Array(Post), name: "user", reverse: true, facets: [priority : Int32]

  def initialize(@firstname, @lastname, @email)
  end
end

describe Dgraph::Base do
  it "creates correct dql_properties" do
    Post.dql_properties.should eq "   uid\n   message\n   user : user{\n     uid\n     firstname\n     lastname\n     email\n     posts : ~user @factets(priority) \n  }\n\n"
    Array(Post).dql_properties.should eq Post.dql_properties
    User.dql_properties.should eq "   uid\n   firstname\n   lastname\n   email\n   posts : ~user @factets(priority) {\n     uid\n     message\n     user : user\n  }\n\n"
  end
end
