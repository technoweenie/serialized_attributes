# supports storing a hash of data as zlib compressed json.
# create a BLOB column and setup your field types for conversion
# and convenient attr methods
#
#   class Profile < ActiveRecord::Base
#     # not needed if used as a rails plugin
#     SerializedAttributes.setup(self)
#
#     # assumes #data serializes to raw_data blob field
#     serialize_attributes do
#       string  :title, :description
#       integer :age
#       float   :rank, :percentage
#       time    :birthday
#     end
#
#     # Serializes #data to assumed raw_data blob field
#     serialize_attributes :data do
#       string  :title, :description
#       integer :age
#       float   :rank, :percentage
#       time    :birthday
#     end
#
#     # set the blob field
#     serialize_attributes :data, :blob => :serialized_field do
#       string  :title, :description
#       integer :age
#       float   :rank, :percentage
#       time    :birthday
#     end
#   end
#
module SerializedAttributes
  require 'serialized_attributes/types'

  if defined?(Rails) && Rails::VERSION::MAJOR <= 2 && Rails::VERSION::MINOR <= 2
    require 'serialized_attributes/duplicable'
  end

  module Format
    autoload :ActiveSupportJson, 'serialized_attributes/format/active_support_json'
  end

  autoload :Schema, 'serialized_attributes/schema'

  add_type :string,  String
  add_type :integer, Integer
  add_type :float,   Float
  add_type :time,    Time
  add_type :boolean, Boolean
  add_type :array,   Array
  add_type :hash,    Hash

  module ModelMethods
    def serialize_attributes(field = :data, options = {}, &block)
      schema = Schema.new(self, field, options)
      schema.instance_eval(&block)
      schema.fields.freeze
      schema
    end
  end
end
