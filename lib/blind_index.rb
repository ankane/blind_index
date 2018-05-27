# dependencies
require "active_support"

# modules
require "blind_index/model"
require "blind_index/version"

module BlindIndex
  class Error < StandardError; end

  def self.generate_bidx(value, key:, iterations: 10000, expression: nil, algorithm: :pbkdf2_hmac, **options)
    key = key.call if key.respond_to?(:call)

    raise BlindIndex::Error, "Missing key for blind index" unless key
    key = key.to_str

    # apply expression
    value = expression.call(value) if expression

    unless value.nil?
      value =
        case algorithm.to_sym
        when :scrypt
          validate_key(key, 32)

          # libsodium equivalent
          # use this script to convert values
          # https://gist.github.com/ankane/5008469d8b25fb614e84883c9285994a
          # RbNaCl::PasswordHash.scrypt(value.to_s, key, 2**20, 2**24, 32)

          SCrypt::Engine.scrypt(value.to_s, key, 4096, 8, 1, 32)
        when :argon2
          validate_key(key, 32)

          # libsodium can't do 32 byte keys
          # 4th argument in bytes for libsodium,kilobytes for argon2
          # RbNaCl::PasswordHash.argon2i(value.to_s, key, 3, 2**26, 32)

          [Argon2::Engine.hash_argon2i(value.to_s, key, 2, 12)].pack("H*")
        when :pbkdf2_hmac
          # TODO enforce key length (or at least a minimum)
          # validate_key(32)

          digest = OpenSSL::Digest::SHA256.new
          OpenSSL::PKCS5.pbkdf2_hmac(value.to_s, key, iterations, digest.digest_length, digest)
        else
          raise ArgumentError, "Unknown algorithm"
        end

      # encode
      [value].pack("m")
    end
  end

  def self.validate_key(key, length)
    raise BlindIndex::Error, "Key must be #{length} bytes" if key.bytesize != length
    # raise BlindIndex::Error, "Key must use BINARY encoding" if key.encoding != Encoding::BINARY
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
