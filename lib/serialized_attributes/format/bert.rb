require 'zlib'
require 'stringio'
require 'bert'

module SerializedAttributes
  module Format
    module Bert
      extend self

      def encode(body)
        return nil if body.blank?
        s = StringIO.new
        z = Zlib::GzipWriter.new(s)
        z.write BERT.encode(body)
        z.close
        s.string
      end

      def decode(body)
        return {} if body.blank?
        s = StringIO.new(body)
        z = Zlib::GzipReader.new(s)
        hash = BERT.decode(z.read)
        z.close
        hash
      end
    end
  end
end