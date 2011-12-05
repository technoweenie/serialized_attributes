require 'zlib'
require 'stringio'

module SerializableAttributes
  module Format
    module ActiveSupportJson
      extend self

      def encode(body)
        return nil if body.blank?
        s = StringIO.new
        z = Zlib::GzipWriter.new(s)
        z.write ActiveSupport::JSON.encode(body)
        z.close
        s.string
      end

      def decode(body)
        return {} if body.to_s.empty?
        s = StringIO.new(body)
        z = Zlib::GzipReader.new(s)
        hash = ActiveSupport::JSON.decode(z.read)
        z.close
        hash
      end
    end
  end
end

