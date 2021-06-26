# dgraph

Dgraph REST client for crystal

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     dgraph:
       github: wonderix/dgraph.cr
   ```

2. Run `shards install`

## Usage

```crystal
require "dgraph"


struct Post
  include Dgraph::Base
  property message : String
  edge user : User
  def initialize(@message, @user)
  end
end

struct User
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  edge posts : Array(Post), reverse: "user", facets: [since : Time]

  def initialize(@firstname, @lastname, @email)
    @posts = nil
  end
end

Dgraph.setup
Dgraph.client.alter(drop_all: true)
Dgraph.client.alter("
    firstname: string @index(trigram,exact) .
    lastname: string @index(trigram,exact) .
    user: uid @reverse .
    type User {
      firstname
      lastname
    }
    type Post {
      user
    }
  ")

user = User.new("Max", "Mustermann", "max.mustermann@web.de").insert
post = Post.new("Hello world", user).insert
p user.uid
p User.all.to_a
p Post.all.to_a
user.delete
```

### Starting dgraph

```bash
mkdir -p ~/dgraph
docker rm -f dpgraph
docker run -d -p 5080:5080 -p 6080:6080 -p 8080:8080   -p 9080:9080 -p 8000:8000 -v ~/dgraph:/dgraph --name dgraph  dgraph/standalone:v21.03.1
```

## Development

TODO: Write development instructions here

### Logging

```bash
export CRYSTAL_LOG_LEVEL=DEBUG
export CRYSTAL_LOG_SOURCE='*'
```

## Contributing

1. Fork it (<https://github.com/wonderix/dgraph.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ulrich Kramer](https://github.com/wonderix) - creator and maintainer
