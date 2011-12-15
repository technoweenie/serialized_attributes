module SerializableAttributes
  class Schema
    class << self
      attr_writer :default_formatter
      def default_formatter
        @default_formatter ||= SerializableAttributes::Format::ActiveSupportJson
      end
    end

    attr_accessor :formatter
    attr_reader :model, :field, :fields

    def all_column_names
      fields ? fields.keys : []
    end

    def encode(body)
      body = body.dup
      body.each do |key, value|
        if field = fields[key]
          body[key] = field.encode(value)
        end
      end
      formatter.encode(body)
    end

    def decode(data, is_new_record = false)
      decoded = formatter.decode(data)
      hash = ::Hash.new do |h, key|
        if type = fields[key]
          h[key] = type ? type.default : nil
        end
      end

      decoded.each do |k, v|
        next unless include?(k)
        type = fields[k]
        hash[k] = type ? type.parse(v) : v
      end

      if decoded.blank? && is_new_record
        fields.each do |key, type|
          hash[key] = type.default if type.default
        end
      end
      hash
    end

    def include?(key)
      @fields.include?(key.to_s)
    end

    # Initializes a new Schema.  See `ModelMethods#serialize_attributes`.
    #
    # model   - The ActiveRecord class.
    # field   - The String name of the ActiveRecord attribute that holds
    #           data.
    # options - Optional Hash:
    #           :blob      - The String name of the actual DB field.  Defaults to
    #                        "raw_#{field}"
    #           :formatter - The module that handles encoding and decoding the
    #                        data.  The default is set in
    #                        `Schema#default_formatter`.
    def initialize(model, field, options)
      @model, @field, @fields = model, field, {}
      @blob_field = options.delete(:blob) || "raw_#{@field}"
      @formatter  = options.delete(:formatter) || self.class.default_formatter
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

      meta_model.send(:define_method, :attribute_names) do
        column_names + send("#{data_field}_schema").all_column_names
      end

      @model.send(:define_method, :reset_serialized_data) do
        instance_variable_set("@#{data_field}", nil)
      end

      @model.send(:define_method, :attribute_names) do
        (super() + send(data_field).keys - [blob_field]).
          map! { |s| s.to_s }.sort!
      end

      @model.send(:define_method, :read_attribute) do |attribute_name|
        schema = self.class.send("#{data_field}_schema")
        if schema.include?(attribute_name)
          data[attribute_name.to_s]
        else
          super(attribute_name)
        end
      end

      if defined?(ActiveRecord::VERSION) && ActiveRecord::VERSION::STRING >= '3.1'
        @model.send(:define_method, :attributes) do
          attributes = super().merge(send(data_field))
          attributes.delete blob_field
          attributes
        end
      end

      @model.send(:define_method, data_field) do
        instance_variable_get("@#{data_field}") || begin
          instance_variable_get("@#{changed_ivar}").clear if send("#{changed_ivar}?")
          schema   = self.class.send("#{data_field}_schema")
          hash     = schema.decode(send(blob_field), new_record?)
          instance_variable_set("@#{data_field}", hash)
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

    # Adds the accessors for a serialized field on this model.  Also sets up
    # the encoders and decoders.
    #
    # type_name - The Symbol matching a valid type.
    # *names    - One or more Symbol field names.
    # options   - Optional Hash to be sent to the initialized Type.
    #             :default - Sets the default value.
    #
    # Returns nothing.
    def field(type_name, *names)
      options      = names.extract_options!
      data_field   = @field
      changed_ivar = "#{data_field}_changed"
      type         = SerializableAttributes.types[type_name].new(options)
      names.each do |name|
        name_str = name.to_s
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

