$LOAD_PATH << File.dirname(__FILE__) + "/lib"
require 'serialized_attributes'
ActiveRecord::Base.extend SerializedAttributes::ModelMethods