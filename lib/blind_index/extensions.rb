module BlindIndex
  module Extensions
    # ActiveRecord 5.0+
    module TableMetadata
      def resolve_column_aliases(hash)
        new_hash = super
        if has_blind_indexes?
          hash.each do |key, _|
            if key.respond_to?(:to_sym) && (bi = klass.blind_indexes[key.to_sym]) && !new_hash[key].is_a?(ActiveRecord::StatementCache::Substitute)
              value = new_hash.delete(key)
              new_hash[bi[:bidx_attribute]] =
                if value.is_a?(Array)
                  value.map { |v| BlindIndex.generate_bidx(v, bi) }
                else
                  BlindIndex.generate_bidx(value, bi)
                end
            end
          end
        end
        new_hash
      end

      # memoize for performance
      def has_blind_indexes?
        unless defined?(@has_blind_indexes)
          @has_blind_indexes = klass.respond_to?(:blind_indexes)
        end
        @has_blind_indexes
      end
    end

    # ActiveRecord 4.2
    module PredicateBuilder
      def resolve_column_aliases(klass, hash)
        new_hash = super
        if has_blind_indexes?(klass)
          hash.each do |key, _|
            if key.respond_to?(:to_sym) && (bi = klass.blind_indexes[key.to_sym]) && !new_hash[key].is_a?(ActiveRecord::StatementCache::Substitute)
              value = new_hash.delete(key)
              new_hash[bi[:bidx_attribute]] =
                if value.is_a?(Array)
                  value.map { |v| BlindIndex.generate_bidx(v, bi) }
                else
                  BlindIndex.generate_bidx(value, bi)
                end
            end
          end
        end
        new_hash
      end

      @@blind_index_cache = {}

      # memoize for performance
      def has_blind_indexes?(klass)
        if @@blind_index_cache[klass].nil?
          @@blind_index_cache[klass] = klass.respond_to?(:blind_indexes)
        end
        @@blind_index_cache[klass]
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

    module DynamicMatchers
      def valid?
        attribute_names.all? { |name| model.columns_hash[name] || model.reflect_on_aggregation(name.to_sym) || blind_index?(name.to_sym) }
      end

      def blind_index?(name)
        model.respond_to?(:blind_indexes) && model.blind_indexes[name]
      end
    end
  end
end
