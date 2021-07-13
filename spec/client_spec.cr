require "./spec_helper"

struct Person
  include JSON::Serializable
  property name : String?
end

describe Dgraph do
  it "works" do
    client = Dgraph::Client.new

    client.alter(drop_all: true)

    client.alter("
      name: string @index(exact) .
      friend: [uid] @reverse .
      age: int .
      married: bool .
      loc: geo .
      dob: datetime .
      type Person {
          name
          friend
          age
          married
          loc
          dob
      }
    ")

    resp = client.mutate(set: [{
      "uid":         "_:alice",
      "dgraph.type": "Person",
      "name":        "Alice",
      "age":         26,
      "married":     true,
      "loc":         {
        "type":        "Point",
        "coordinates": [1.1, 2],
      },
      "dob":    Time.local(1980, 1, 1, 23, 0, 0),
      "friend": [
        {
          "uid":         "_:bob",
          "dgraph.type": "Person",
          "name":        "Bob",
          "age":         24,
        },
      ],
      "school": [
        {
          "name": "Crown Public School",
        },
      ],
    }])
    uids = resp.uids
    uids["alice"].should_not be_nil
    uids["bob"].should_not be_nil
    variables = Hash(String, Dgraph::Types).new
    variables["$a"] = "Alice"
    result = client.query("query all($a: string) {
        all(func: eq(name, $a)) {
            uid
            name
            age
            married
            loc
            dob
            friend {
                name
                age
            }
            school {
                name
            }
        }
    }", variables).map { |p| Person.new(p) }.to_a
    result[0].name.should eq "Alice"

    client.mutate(delete: [{"uid" => uids["alice"], "uid" => uids["bob"]}])
  end
end
