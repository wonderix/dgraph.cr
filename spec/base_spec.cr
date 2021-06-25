require "./spec_helper"

struct Post
  include Dgraph::Base
  property message : String

  def initialize(@message)
  end
end

struct User
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  property posts : Array(Post)?

  def initialize(@firstname, @lastname, @email, @posts)
  end
end

describe Dgraph::Base do
  it "creates correct dql_properties" do
    Post.dql_properties.should eq "uid\nmessage\n"
    Array(Post).dql_properties.should eq "uid\nmessage\n"
    User.dql_properties.should eq "uid\nfirstname\nlastname\nemail\nposts\n{\nuid\nmessage\n}\n"
  end
end
