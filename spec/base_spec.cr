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
    User.dql_properties.should contain "uid\nfirstname\nlastname\nemail\nposts\n"
  end
end
