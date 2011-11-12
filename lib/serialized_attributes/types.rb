module SerializedAttributes
  class AttributeType
    def initialize(options = {})
      @default = options[:default]
    end

    def encode(s) s end

    def type_for(key)
      SerializedAttributes.const_get(key.to_s.classify).new
    end

    def default
      @default && @default.respond_to?(:dup) ? @default.dup : @default
    end
  end

  class Integer < AttributeType
    attr_reader :default
    def parse(input)  input.blank? ? nil : input.to_i end
  end

  class Float < AttributeType
    attr_reader :default
    def parse(input)  input.blank? ? nil : input.to_f end
  end

  class Boolean < AttributeType
    attr_reader :default
    def parse(input)
      return nil if input == ""
      input && input.respond_to?(:to_i) ? (input.to_i > 0) : input
    end

    def encode(input)
      return nil if input.nil? || input == ""
      return 1 if input == 'true'
      return 0 if input == 'false'

      input ? 1 : 0
    end
  end

  class String < AttributeType
    # converts unicode (\u003c) to the actual character
    # http://rishida.net/tools/conversion/
    def parse(str)
      return nil if str.nil?
      str = str.to_s
      str.gsub!(/\\u([0-9a-fA-F]{4})/) do |s|
        int = $1.to_i(16)
        if int.zero? && s != "0000"
          s
        else
          [int].pack("U")
        end
      end
      str
    end
  end

  class Time < AttributeType
    def parse(input)
      return nil if input.blank?
      case input
        when ::Time   then input
        when ::String then ::Time.parse(input)
        else input.to_time
      end
    end
    def encode(input) input ? input.utc.xmlschema : nil end
  end

  class Array < AttributeType
    def initialize(options = {})
      super
      @item_type = type_for(options[:type] || "String")
    end

    def parse(input)
      if input.nil?
        nil
      elsif input.blank?
        []
      else
        input.map! { |item| @item_type.parse(item) }
      end
    end

    def encode(input)
      if input.nil?
        nil
      elsif input.blank?
        []
      else
        input.map! { |item| @item_type.encode(item) }
      end
    end
  end

  class Hash < AttributeType
    def initialize(options = {})
      super
      @key_type = String.new
      @types    = (options[:types] || {})
      @types.keys.each do |key|
        value = @types.delete(key)
        @types[key.to_s] = type_for(value)
      end
    end

    def parse(input)
      return nil if input.blank?
      input.keys.each do |key|
        value = input.delete(key)
        key_s = @key_type.parse(key)
        type  = @types[key_s] || @key_type
        input[key_s] = type.parse(value)
      end
      input
    end

    def encode(input)
      return nil if input.blank?
      input.each do |key, value|
        type = @types[key] || @key_type
        input[key] = type.encode(value)
      end
    end
  end

  class << self
    attr_accessor :types
    def add_type(type, object = nil)
      types[type] = object
      Schema.send(:define_method, type) do |*names|
        field type, *names
      end
    end
  end
  self.types = {}
end
