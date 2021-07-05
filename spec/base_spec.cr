require "./spec_helper"

struct Post
  include Dgraph::Base
  property message : String
  edge user : User

  def initialize(@message)
  end
end

struct PostEdge
  include Dgraph::Edge(Post)
  enum Priority
    Low
    High
  end
  property priority : Priority = Priority::High

  def initialize(@ref, @priority)
  end
end

struct User
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  edge posts : PostEdge, name: "user", reverse: true

  def initialize(@firstname, @lastname, @email)
  end
end

describe Dgraph::Base do
  it "creates correct dql_properties" do
    PostEdge.dql_properties.should eq " @facets(priority){\n   uid\n   message\n   user : user{\n     uid\n     firstname\n     lastname\n     email\n     user : ~user @facets(priority)\n  }\n\n}\n"
    Post.dql_properties.should eq "{\n   uid\n   message\n   user : user{\n     uid\n     firstname\n     lastname\n     email\n     user : ~user @facets(priority)\n  }\n\n}\n"
    Array(Post).dql_properties.should eq Post.dql_properties
    User.dql_properties.should eq "{\n   uid\n   firstname\n   lastname\n   email\n   user : ~user @facets(priority){\n     uid\n     message\n     user : user\n  }\n\n}\n"

    user = User.new("Max", "Mustermann", "test")
    user.posts = [PostEdge.new(Post.new("Hello world!"), PostEdge::Priority::High)]
    # Field posts must be user in JSON
    json = user.to_json
    json.should eq "{\"firstname\":\"Max\",\"lastname\":\"Mustermann\",\"email\":\"test\",\"user\":[{\"message\":\"Hello world!\",\"dgraph.type\":\"Post\",\"user|priority\":\"high\"}],\"dgraph.type\":\"User\"}"

    user = User.from_json(json)
    user.posts[0].priority.should eq PostEdge::Priority::High
    user.posts[0].ref.message.should eq "Hello world!"
  end
end
