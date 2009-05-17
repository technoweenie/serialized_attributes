require 'zlib'
require 'stringio'

# supports storing a hash of data as zlib compressed json.
# create a BLOB column and setup your field types for conversion
# and convenient attr methods
#
#   class Profile < ActiveRecord::Base
#     SerializedAttributes.setup(self)
#
#     serialize_attributes :data do
#       string  :title, :description
#       integer :age
#       float   :rank, :percentage
#       time    :birthday
#     end
#   end
#
module SerializedAttributes
  module Integer
    def self.parse(input)  input.blank? ? nil : input.to_i end
    def self.encode(input) input          end
  end

  module Float
    def self.parse(input)  input.blank? ? nil : input.to_f end
    def self.encode(input) input          end
  end

  module Boolean
    def self.parse(input)  input && input.respond_to?(:to_i) ? (input.to_i > 0) : input end
    def self.encode(input) input ? 1 : 0  end
  end

  module Time
    def self.parse(input)
      return nil if input.blank?
      case input
        when Time   then input
        when String then ::Time.parse(input)
        else input.to_time
      end
    end
    def self.encode(input) input ? input.utc.xmlschema : nil end
  end

  @@types = {
    :string  => nil,
    :integer => Integer,
    :float   => Float,
    :time    => Time,
    :boolean => Boolean
  }

  def self.types() @@types end

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

    def initialize(model, field)
      @model, @field, @fields = model, field, {}
      blob_field = @field
      raw_field  = @raw      = "raw_#{@field}"
      meta_model = class << @model; self; end
      raw_changed_ivar = "#{@raw}_changed"
      meta_model.send(:attr_accessor, "#{@field}_schema")
      @model.send("#{@field}_schema=", self)
      @model.send(:define_method, @raw) do
        instance_variable_get("@#{raw_field}") || begin
          decoded = SerializedAttributes::Schema.decode(send(blob_field))
          schema  = self.class.send("#{blob_field}_schema")
          hash    = {}
          instance_variable_set("@#{raw_field}", hash)
          decoded.each do |k, v|
            next unless schema.include?(k)
            send("#{k}=", v)
          end
          instance_variable_get("@#{raw_changed_ivar}").clear if send("#{raw_changed_ivar}?")
          hash
        end
      end

      @model.send(:define_method, :write_serialized_field) do |name, value|
        raw_data = send(raw_field) # load fields if needed
        name_str = name.to_s
        schema   = self.class.send("#{blob_field}_schema")
        type     = schema.fields[name_str]
        changed_fields = send(raw_changed_ivar)
        instance_variable_get("@#{raw_changed_ivar}")[name_str] = raw_data[name_str] unless changed_fields.include?(name_str)
        parsed_value = type ? type.parse(value) : value
        if parsed_value.nil?
          raw_data.delete(name_str)
        else
          raw_data[name_str] = parsed_value
        end
        parsed_value
      end

      @model.send(:define_method, raw_changed_ivar) do
        hash = instance_variable_get("@#{raw_changed_ivar}") || instance_variable_set("@#{raw_changed_ivar}", {})
        hash.keys
      end

      @model.send(:define_method, "#{raw_changed_ivar}?") do
        !send(raw_changed_ivar).empty?
      end

      @model.before_save do |r|
        schema = r.class.send("#{blob_field}_schema")
        r.send("#{blob_field}=", schema.encode(r.send(raw_field)))
      end
    end

    def field(type_name, *names)
      names.each do |name|
        raw_data_name     = @raw
        raw_changed_ivar  = "#{@raw}_changed"
        name_str          = name.to_s
        type              = SerializedAttributes.types[type_name]
        @fields[name_str] = type
        @model.send(:define_method, name) do
          send(raw_data_name)[name_str]
        end

        @model.send(:define_method, "#{name}=") do |value|
          write_serialized_field name_str, value
        end

        @model.send(:define_method, "#{name}_changed?") do
          send(raw_changed_ivar).include?(name_str)
        end

        @model.send(:define_method, "#{name}_before_type_cast") do
          value = send(name)
          value = type.encode(value) if type
          value.to_s
        end

        @model.send(:define_method, "#{name}_change") do
          if send("#{name}_changed?")
            [instance_variable_get("@#{raw_changed_ivar}")[name_str], send(raw_data_name)[name_str]]
          else
            nil
          end
        end
      end
    end

    def string(*names)
      field :string, *names
    end

    def integer(*names)
      field :integer, *names
    end

    def float(*names)
      field :float, *names
    end

    def time(*names)
      field :time, *names
    end

    def boolean(*names)
      field :boolean, *names
    end
  end

  def self.setup(base)
    base.extend ModelMethods
  end

  module ModelMethods
    def serialize_attributes(field = :data, &block)
      schema = Schema.new(self, field)
      schema.instance_eval(&block)
      schema.fields.freeze
      schema
    end
  end
end