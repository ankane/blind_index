module BlindIndex
  class KeyGenerator
    def initialize(master_key)
      @master_key = master_key
    end

    # pattern ported from CipherSweet
    # https://ciphersweet.paragonie.com/internals/key-hierarchy
    def index_key(table:, bidx_attribute:)
      raise ArgumentError, "Missing table for key generation" if table.to_s.empty?
      raise ArgumentError, "Missing field for key generation" if bidx_attribute.to_s.empty?

      c = "\x7E"*32
      root_key = hkdf(BlindIndex.decode_key(@master_key, name: "Master key"), salt: table.to_s, info: "#{c}#{bidx_attribute}", length: 32, hash: "sha384")
      hash_hmac("sha256", pack([table, bidx_attribute, bidx_attribute]), root_key)
    end

    private

    def hash_hmac(hash, ikm, salt)
      OpenSSL::HMAC.digest(hash, salt, ikm)
    end

    def hkdf(ikm, salt:, info:, length:, hash:)
      if defined?(OpenSSL::KDF.hkdf)
        return OpenSSL::KDF.hkdf(ikm, salt: salt, info: info, length: length, hash: hash)
      end

      prk = hash_hmac(hash, ikm, salt)

      # empty binary string
      t = String.new
      last_block = String.new
      block_index = 1
      while t.bytesize < length
        last_block = hash_hmac(hash, last_block + info + [block_index].pack("C"), prk)
        t << last_block
        block_index += 1
      end

      t[0, length]
    end

    def pack(pieces)
      output = String.new
      output << [pieces.size].pack("V")
      pieces.map(&:to_s).each do |piece|
        output << [piece.bytesize].pack("Q<")
        output << piece
      end
      output
    end
  end
end
