require File.expand_path('../serialized_attributes', __FILE__)
module SerializedAttributes
  VERSION = "0.9.0"
end

Object.const_set :SerializableAttributes, SerializedAttributes
