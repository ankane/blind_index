module BlindIndex
  module Extensions
    module TableMetadata
      if ActiveRecord::VERSION::MAJOR >= 5
        def resolve_column_aliases(hash)
          new_hash = super
          if has_blind_indexes?
            hash.each do |key, _|
              if (bi = klass.blind_indexes[key])
                new_hash[bi[:bidx_attribute]] = BlindIndex.generate_bidx(new_hash.delete(key), bi)
              end
            end
          end
          new_hash
        end
      else
        def resolve_column_aliases(klass, hash)
          new_hash = super
          if klass.respond_to?(:blind_indexes)
            hash.each do |key, _|
              if (bi = klass.blind_indexes[key])
                new_hash[bi[:bidx_attribute]] = BlindIndex.generate_bidx(new_hash.delete(key), bi)
              end
            end
          end
          new_hash
        end
      end

      # memoize for performance
      def has_blind_indexes?
        unless defined?(@has_blind_indexes)
          @has_blind_indexes = klass.respond_to?(:blind_indexes)
        end
        @has_blind_indexes
      end
    end

    module UniquenessValidator
      if ActiveRecord::VERSION::STRING >= "5.2"
        def build_relation(klass, attribute, value)
          if klass.respond_to?(:blind_indexes) && (bi = klass.blind_indexes[attribute])
            value = BlindIndex.generate_bidx(value, bi)
            attribute = bi[:bidx_attribute]
          end
          super(klass, attribute, value)
        end
      else
        def build_relation(klass, table, attribute, value)
          if klass.respond_to?(:blind_indexes) && (bi = klass.blind_indexes[attribute])
            value = BlindIndex.generate_bidx(value, bi)
            attribute = bi[:bidx_attribute]
          end
          super(klass, table, attribute, value)
        end
      end
    end
  end
end
