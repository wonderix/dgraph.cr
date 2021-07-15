require "./spec_helper"

struct User
end

struct Post
  include Dgraph::Base
  property message : String
  edge user : User

  def initialize(@message)
  end
end

struct Posting
  include Dgraph::Facets
  property priority : Int32

  def initialize(@priority = 0)
  end
end

struct User
  include Dgraph::Base
  property given_name : String
  property family_name : String
  property email : String
  edge posts : Array(Dgraph::Edge(Post, Posting)), name: "user", reverse: true

  def initialize(@given_name, @family_name, @email)
  end
end

describe Dgraph::Base do
  Dgraph.setup
  client = Dgraph.client

  client.alter(drop_all: true)

  client.alter("
    user: uid @reverse .
    given_name : string @index(exact) .
    family_name : string @index(exact) .
    type Post {
      user
    }
    type User {
      family_name
      given_name
    }
  ")

  it "creates correct dql_properties" do
    Dgraph::Edge(Post, Posting).dql_properties.should eq " @facets(priority){\n   uid\n   message\n   user{\n     uid\n     given_name\n     family_name\n     email\n     user : ~user @facets(priority)\n  }\n\n}\n"
    Post.dql_properties.should eq "{\n   uid\n   message\n   user{\n     uid\n     given_name\n     family_name\n     email\n     user : ~user @facets(priority)\n  }\n\n}\n"
    Array(Post).dql_properties.should eq Post.dql_properties
    User.dql_properties.should eq "{\n   uid\n   given_name\n   family_name\n   email\n   user : ~user @facets(priority){\n     uid\n     message\n     user\n  }\n\n}\n"

    user = User.new("Max", "Mustermann", "test")
    user.posts = [Dgraph::Edge.new(Post.new("Hello world!"), Posting.new(1))]
    # reverse edges are not serialized
    user.to_json.should eq "{\"given_name\":\"Max\",\"family_name\":\"Mustermann\",\"email\":\"test\",\"dgraph.type\":\"User\"}"

    # normal edges are serialized
    post = Post.new("Hello")
    post.user = user
    post.to_json.should eq "{\"message\":\"Hello\",\"user\":{\"given_name\":\"Max\",\"family_name\":\"Mustermann\",\"email\":\"test\",\"dgraph.type\":\"User\"},\"dgraph.type\":\"Post\"}"

    user = User.from_json("{\"given_name\":\"Max\",\"family_name\":\"Mustermann\",\"email\":\"test\",\"user\":[{\"message\":\"Hello world!\",\"dgraph.type\":\"Post\",\"user|priority\":1}],\"dgraph.type\":\"User\"}")
    user.posts[0].facets.priority.should eq 1
    user.posts[0].value.message.should eq "Hello world!"
  end

  it "query is working" do
    max = User.insert("Max", "Mustermann", "max.musterman@mail.com")
    erika = User.insert("Erika", "Mustermann", "max.musterman@mail.com")
    User.get(max.uid).given_name.should eq "Max"
    User.get(erika.uid).given_name.should eq "Erika"
    User.where(given_name: "Max").each.size.should eq 1
    User.where(family_name: "Mustermann").each.size.should eq 2
  end
end
