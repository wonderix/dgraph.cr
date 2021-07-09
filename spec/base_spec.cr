require "./spec_helper"

struct Post
  include Dgraph::Base
  property message : String
  edge user : User

  def initialize(@message)
  end
end

struct Posting
  include Dgraph::Facets
  property priority : Int32 = 0

  def initialize(@priority)
  end
end

struct User
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  edge posts : Array(Dgraph::Edge(Post, Posting)), name: "user", reverse: true

  def initialize(@firstname, @lastname, @email)
  end
end

describe Dgraph::Base do
  it "creates correct dql_properties" do
    Dgraph::Edge(Post, Posting).dql_properties.should eq " @facets(priority){\n   uid\n   message\n   user : user{\n     uid\n     firstname\n     lastname\n     email\n     user : ~user @facets(priority)\n  }\n\n}\n"
    Post.dql_properties.should eq "{\n   uid\n   message\n   user : user{\n     uid\n     firstname\n     lastname\n     email\n     user : ~user @facets(priority)\n  }\n\n}\n"
    Array(Post).dql_properties.should eq Post.dql_properties
    User.dql_properties.should eq "{\n   uid\n   firstname\n   lastname\n   email\n   user : ~user @facets(priority){\n     uid\n     message\n     user : user\n  }\n\n}\n"

    user = User.new("Max", "Mustermann", "test")
    user.posts = [Dgraph::Edge.new(Post.new("Hello world!"), Posting.new(1))]
    # Field posts must be user in JSON
    json = user.to_json
    json.should eq "{\"firstname\":\"Max\",\"lastname\":\"Mustermann\",\"email\":\"test\",\"user\":[{\"message\":\"Hello world!\",\"dgraph.type\":\"Post\",\"user|priority\":1}],\"dgraph.type\":\"User\"}"

    user = User.from_json(json)
    user.posts[0].facets.priority.should eq 1
    user.posts[0].value.message.should eq "Hello world!"
  end
end
