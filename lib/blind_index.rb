# dependencies
require "active_support"

# modules
require "blind_index/model"
require "blind_index/version"

module BlindIndex
  class Error < StandardError; end

  class << self
    attr_accessor :default_options
  end
  self.default_options = {
    iterations: 10000,
    algorithm: :pbkdf2_hmac,
    insecure_key: false,
    encode: true,
    cost: {}
  }

  def self.generate_bidx(value, key:, **options)
    options = default_options.merge(options)

    # apply expression
    value = options[:expression].call(value) if options[:expression]

    unless value.nil?
      algorithm = options[:algorithm].to_sym

      key = key.call if key.respond_to?(:call)
      raise BlindIndex::Error, "Missing key for blind index" unless key

      key = key.to_s
      unless options[:insecure_key] && algorithm == :pbkdf2_hmac
        raise BlindIndex::Error, "Key must use binary encoding" if key.encoding != Encoding::BINARY
        # raise BlindIndex::Error, "Key must not be ASCII" if key.bytes.all? { |b| b < 128 }
        raise BlindIndex::Error, "Key must be 32 bytes" if key.bytesize != 32
      end

      # gist to compare algorithm results
      # https://gist.github.com/ankane/fe3ac63fbf1c4550ee12554c664d2b8c
      cost_options = options[:cost]

      value =
        case algorithm
        when :scrypt
          n = cost_options[:n] || 4096
          r = cost_options[:r] || 8
          cp = cost_options[:p] || 1
          SCrypt::Engine.scrypt(value.to_s, key, n, r, cp, 32)
        when :argon2
          t = cost_options[:t] || 3
          m = cost_options[:m] || 12
          [Argon2::Engine.hash_argon2i(value.to_s, key, t, m)].pack("H*")
        when :pbkdf2_hmac
          iterations = cost_options[:iterations] || options[:iterations]
          OpenSSL::PKCS5.pbkdf2_hmac(value.to_s, key, iterations, 32, "sha256")
        else
          raise BlindIndex::Error, "Unknown algorithm"
        end

      encode = options[:encode]
      if encode
        if encode.respond_to?(:call)
          encode.call(value)
        else
          [value].pack("m")
        end
      else
        value
      end
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
