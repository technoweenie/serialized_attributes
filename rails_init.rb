require File.expand_path('../lib/serializable_attributes', __FILE__)
ActiveRecord::Base.extend SerializedAttributes::ModelMethods

