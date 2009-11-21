module SerializedAttributes
  class Schema
    class << self
      attr_writer :default_schema
      def default_schema
        @default_schema ||= SerializedAttributes::Format::ActiveSupportJson
      end
    end

    attr_accessor :formatter
    attr_reader :model, :field, :fields

    def encode(body)
      body = body.dup
      body.each do |key, value|
        if field = fields[key]
          body[key] = field.encode(value)
        end
      end
      formatter.encode(body)
    end

    def include?(key)
      @fields.include?(key.to_s)
    end

    def initialize(model, field, options)
      @model, @field, @fields = model, field, {}
      @blob_field = options.delete(:blob) || "raw_#{@field}"
      @formatter  = options.delete(:formatter) || self.class.default_schema
      blob_field  = @blob_field
      data_field  = @field

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
        (super + send(data_field).keys - [blob_field]).map! { |s| s.to_s }.sort!
      end

      @model.send(:define_method, data_field) do
        instance_variable_get("@#{data_field}") || begin
          instance_variable_get("@#{changed_ivar}").clear if send("#{changed_ivar}?")
          schema   = self.class.send("#{data_field}_schema")
          decoded  = schema.formatter.decode(send(blob_field))
          hash     = Hash.new do |(h, key)|
            type   = schema.fields[key]
            h[key] = type ? type.default : nil
          end
          instance_variable_set("@#{data_field}", hash)
          decoded.each do |k, v|
            next unless schema.include?(k)
            type = schema.fields[k]
            hash[k] = type ? type.parse(v) : v
          end
          if decoded.blank? && new_record?
            schema.fields.each do |key, type|
              hash[key] = type.default if type.default
            end
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
        type              = SerializedAttributes.types[type_name].new(options)
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
end