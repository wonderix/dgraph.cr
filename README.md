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

struct Employment
  include Dgraph::Facets
  property salery : Int32
  property role : Int32

  def initialize(@salery, @role)
  end
end

struct Person
end

struct Company
  include Dgraph::Base
  property name : String
  edge peoples : Array(Dgraph::Edge(Person, Employment)), name: "company", reverse: true

  def initialize(@name)
  end
end

struct Person
  include Dgraph::Base
  property firstname : String
  property lastname : String
  property email : String
  edge company : Dgraph::Edge(Company, Employment), name: "company"

  def initialize(@firstname, @lastname, @email, @company)
  end
end

Dgraph.setup
Dgraph.client.alter(drop_all: true)
Dgraph.client.alter("
    firstname: string @index(trigram,exact) .
    lastname: string @index(trigram,exact) .
    company: uid @reverse .
    type Person {
      firstname
      lastname
      company
    }
    type Company {
    }
  ")

company = Company.new("Enterprise").insert
person = Person.new("Max", "Mustermann", "max.mustermann@web.de", Dgraph::Edge.new(company, Employment.new(10000, 1))).insert
p person.uid
p Person.get(person.uid)
p Person.all.to_a
p Company.all.to_a
person.delete
```

### Starting dgraph

```bash
mkdir -p ~/dgraph
docker rm -f dpgraph || true
docker run -d -p 5080:5080 -p 6080:6080 -p 8080:8080   -p 9080:9080 -p 8000:8000 -v ~/dgraph:/dgraph --name dgraph  dgraph/standalone:v21.03.1
```

## Development

TODO: Write development instructions here

### Logging

See [Log](https://crystal-lang.org/api/1.0.0/Log.html)

## Contributing

1. Fork it (<https://github.com/wonderix/dgraph.cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Ulrich Kramer](https://github.com/wonderix) - creator and maintainer
