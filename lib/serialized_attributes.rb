require 'zlib'
require 'stringio'

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
  class AttributeType
    attr_reader :default
    def initialize(default = nil)
      @default = default
    end
    def encode(s) s end
  end

  class Integer < AttributeType
    def parse(input)  input.blank? ? nil : input.to_i end
  end

  class Float < AttributeType
    def parse(input)  input.blank? ? nil : input.to_f end
  end

  class Boolean < AttributeType
    def parse(input)  input && input.respond_to?(:to_i) ? (input.to_i > 0) : input end
    def encode(input) input ? 1 : 0  end
  end

  class String < AttributeType
    # converts unicode (\u003c) to the actual character
    def parse(str)
      return nil if str.nil?
      str = str.to_s
      str.gsub!(/\\u([0-9a-z]{4})/i) { |s| [$1.to_i(16)].pack("U") }
      str
    end
  end

  class Time < AttributeType
    def parse(input)
      return nil if input.blank?
      case input
        when Time   then input
        when String then ::Time.parse(input)
        else input.to_time
      end
    end
    def encode(input) input ? input.utc.xmlschema : nil end
  end

  @@types = {}
  mattr_reader :types
  def self.add_type(type, object = nil)
    @@types[type] = object
    Schema.send(:define_method, type) do |*names|
      field type, *names
    end
  end

  class Schema
    attr_reader :model, :field, :fields

    def self.encode(body)
      return nil if body.blank?
      s = StringIO.new
      z = Zlib::GzipWriter.new(s)
      z.write ActiveSupport::JSON.encode(body)
      z.close
      s.string
    end

    def self.decode(body)
      return {} if body.blank?
      s = StringIO.new(body)
      z = Zlib::GzipReader.new(s)
      hash = ActiveSupport::JSON.decode(z.read)
      z.close
      hash
    end

    def encode(body)
      body = body.dup
      body.each do |key, value|
        if field = fields[key]
          body[key] = field.encode(value)
        end
      end
      self.class.encode(body)
    end

    def include?(key)
      @fields.include?(key.to_s)
    end

    def initialize(model, field, options)
      @model, @field, @fields = model, field, {}
      @blob_field = options.delete(:blob) || "raw_#{@field}"
      blob_field = @blob_field
      data_field = @field

      meta_model = class << @model; self; end
      changed_ivar = "#{data_field}_changed"
      meta_model.send(:attr_accessor, "#{data_field}_schema")
      @model.send("#{data_field}_schema=", self)

      @model.class_eval do
        def reload(options = nil)
          reset_serialized_data
          super
        end
      end

      @model.send(:define_method, :reset_serialized_data) do
        instance_variable_set("@#{data_field}", nil)
      end

      @model.send(:define_method, :attribute_names) do
        (super + send(data_field).keys - [blob_field]).sort
      end

      @model.send(:define_method, data_field) do
        instance_variable_get("@#{data_field}") || begin
          instance_variable_get("@#{changed_ivar}").clear if send("#{changed_ivar}?")
          decoded = SerializedAttributes::Schema.decode(send(blob_field))
          schema  = self.class.send("#{data_field}_schema")
          hash    = Hash.new do |(h, key)|
            type   = schema.fields[key]
            h[key] = type ? type.default : nil
          end
          instance_variable_set("@#{data_field}", hash)
          decoded.each do |k, v|
            next unless schema.include?(k)
            type = schema.fields[k]
            hash[k] = type ? type.parse(v) : v
          end
          hash
        end
      end

      @model.send(:define_method, :write_serialized_field) do |name, value|
        raw_data = send(data_field) # load fields if needed
        name_str = name.to_s
        schema   = self.class.send("#{data_field}_schema")
        type     = schema.fields[name_str]
        changed_fields = send(changed_ivar)
        instance_variable_get("@#{changed_ivar}")[name_str] = raw_data[name_str] unless changed_fields.include?(name_str)
        parsed_value = type ? type.parse(value) : value
        if parsed_value.nil?
          raw_data.delete(name_str)
        else
          raw_data[name_str] = parsed_value
        end
        parsed_value
      end

      @model.send(:define_method, changed_ivar) do
        hash = instance_variable_get("@#{changed_ivar}") || instance_variable_set("@#{changed_ivar}", {})
        hash.keys
      end

      @model.send(:define_method, "#{changed_ivar}?") do
        !send(changed_ivar).empty?
      end

      @model.before_save do |r|
        schema = r.class.send("#{data_field}_schema")
        r.send("#{blob_field}=", schema.encode(r.send(data_field)))
      end
    end

    def field(type_name, *names)
      options      = names.extract_options!
      data_field   = @field
      changed_ivar = "#{data_field}_changed"
      names.each do |name|
        name_str          = name.to_s
        type              = SerializedAttributes.types[type_name].new(options[:default])
        @fields[name_str] = type

        @model.send(:define_method, name) do
          send(data_field)[name_str]
        end

        if type.is_a? Boolean
          @model.send :alias_method, "#{name}?", name
        end

        @model.send(:define_method, "#{name}=") do |value|
          write_serialized_field name_str, value
        end

        @model.send(:define_method, "#{name}_changed?") do
          send(changed_ivar).include?(name_str)
        end

        @model.send(:define_method, "#{name}_before_type_cast") do
          value = send(name)
          value = type.encode(value) if type
          value.to_s
        end

        @model.send(:define_method, "#{name}_change") do
          if send("#{name}_changed?")
            [instance_variable_get("@#{changed_ivar}")[name_str], send(data_field)[name_str]]
          else
            nil
          end
        end
      end
    end
  end

  add_type :string,  String
  add_type :integer, Integer
  add_type :float,   Float
  add_type :time,    Time
  add_type :boolean, Boolean

  module ModelMethods
    def serialize_attributes(field = :data, options = {}, &block)
      schema = Schema.new(self, field, options)
      schema.instance_eval(&block)
      schema.fields.freeze
      schema
    end
  end
end