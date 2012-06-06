# create a BLOB column and setup your field types for conversion
# and convenient attr methods
#
#   class Profile < ActiveRecord::Base
#     # not needed if used as a rails plugin
#     SerializableAttributes.setup(self)
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
module SerializableAttributes
  VERSION = "1.1.0"

  require File.expand_path('../serializable_attributes/types', __FILE__)
  require File.expand_path('../serializable_attributes/schema', __FILE__)

  if nil.respond_to?(:duplicable?)
    require File.expand_path('../serializable_attributes/duplicable', __FILE__)
  end

  module Format
    autoload :ActiveSupportJson, File.expand_path('../serializable_attributes/format/active_support_json', __FILE__)
  end

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

  # Install the plugin for the given model class.
  #
  # active_record - A class to install the plugin.  Default: ActiveRecord::Base.
  #
  # Returns nothing.
  def self.setup(active_record = ActiveRecord::Base)
    active_record.extend ModelMethods
  end
end

# Backwards compatible hack.
Object.const_set :SerializedAttributes, SerializableAttributes
