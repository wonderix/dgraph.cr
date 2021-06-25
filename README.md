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
  def initialize(@message)
  end
end

struct User
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  property posts : [] of Posts
  def initialize(@firstname, @lastname,  @email, @posts)
  end
end

Dgraph.setup
Dgraph.client.alter("
  firstname: string @index(trigram,exact) .
  lastname: string @index(trigram,exact) .
  posts: [uid] @reverse .
  type User {
    firstname
    lastname
    posts
  }
  type Post {

  }
")

user = User.new("Max","Mustermann","max.mustermann@web.de")

user.insert
p user.uid

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
