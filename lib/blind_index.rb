# dependencies
require "active_support"

# modules
require "blind_index/model"
require "blind_index/version"

module BlindIndex
  class Error < StandardError; end

  def self.generate_bidx(value, key:, iterations:, expression: nil, **options)
    key = key.call if key.respond_to?(:call)

    raise BlindIndex::Error, "Missing key for blind index" unless key
    # key = key.to_str
    # raise BlindIndex::Error, "Key must be 32 bytes" if key.bytesize != 32
    # raise BlindIndex::Error, "Key must use BINARY encoding" if key.encoding != Encoding::BINARY

    # apply expression
    value = expression.call(value) if expression

    unless value.nil?
      # generate hash
      digest = OpenSSL::Digest::SHA256.new
      value = OpenSSL::PKCS5.pbkdf2_hmac(value.to_s, key, iterations, digest.digest_length, digest)

      # encode
      [value].pack("m")
    end
  end
end

ActiveSupport.on_load(:active_record) do
  require "blind_index/extensions"
  extend BlindIndex::Model

  if defined?(ActiveRecord::TableMetadata)
    ActiveRecord::TableMetadata.prepend(BlindIndex::Extensions::TableMetadata)
  else
    ActiveRecord::PredicateBuilder.singleton_class.prepend(BlindIndex::Extensions::PredicateBuilder)
  end

  unless ActiveRecord::VERSION::STRING.start_with?("5.1.")
    ActiveRecord::Validations::UniquenessValidator.prepend(BlindIndex::Extensions::UniquenessValidator)
  end
end
