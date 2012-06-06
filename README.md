# SerializedAttributes

SerializedAttributes allows you to add an encoded hash to an ActiveRecord model.
This is similar to the built-in ActiveRecord serialization, except that the field
is converted to JSON, gzipped, and stored in a BLOB field.  This uses the json
gem which is much faster than YAML serialization.  However, JSON is not nearly as
flexible, so you're stuck with strings/integers/dates/etc.

Where possible, ActiveRecord compatible methods are generated so that a migration
should be pretty simple.  See unit tests for examples.

Some of the code and most of the ideas are taken from [Heresy][Heresy], a ruby
implementation of [how FriendFeed uses MySQL for schema-free storage][schemafree].

Supports ActiveRecord 2.2 in ruby 1.8.7, and ActiveRecord 2.3-3.1 in ruby 1.9.3.
See [Travis CI][travis] to see if we support your version of
ActiveRecord and ruby.

[Heresy]: https://github.com/kabuki/heresy
[schemafree]: http://bret.appspot.com/entry/how-friendfeed-uses-mysql
[travis]: http://travis-ci.org/#!/technoweenie/serialized_attributes

## Setup

    gem install serializable_attributes

Sorry for the confusion, but someone took the `serialized_attributes`
gem name.  I wouldn't mind giving it a completely new name before a
"1.0" release though.

## Usage

```ruby
class Profile < ActiveRecord::Base
  # assumes #data serializes to raw_data blob field
  serialize_attributes do
    string  :title, :description
    integer :age
    float   :rank, :percentage
    time    :birthday
  end

  # Serializes #data to assumed raw_data blob field
  serialize_attributes :data do
    string  :title, :description
    integer :age
    float   :rank, :percentage
    time    :birthday
  end

  # set the blob field
  serialize_attributes :data, :blob => :serialized_field do
    string  :title, :description
    integer :age
    float   :rank, :percentage
    time    :birthday
  end
end
```
