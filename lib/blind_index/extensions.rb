module BlindIndex
  module Extensions
    module TableMetadata
      def resolve_column_aliases(hash)
        new_hash = super
        if has_blind_indexes?
          hash.each_key do |key|
            if key.respond_to?(:to_sym) && (bi = klass.blind_indexes[key.to_sym]) && !new_hash[key].is_a?(ActiveRecord::StatementCache::Substitute)
              value = new_hash.delete(key)
              new_hash[bi[:bidx_attribute]] =
                if value.is_a?(Array)
                  value.map { |v| BlindIndex.generate_bidx(v, **bi) }
                else
                  BlindIndex.generate_bidx(value, **bi)
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

    # Active Record 6.1+
    # https://github.com/rails/rails/commit/56f30962b84fc53b76001301fb830c1594fd377e
    module PredicateBuilder
      def build(attribute, value, operator = nil)
        if table.has_blind_indexes? && (bi = table.send(:klass).blind_indexes[attribute.name.to_sym]) && !value.is_a?(ActiveRecord::StatementCache::Substitute)
          attribute = attribute.relation[bi[:bidx_attribute]]
          value =
            if value.is_a?(Array)
              value.map { |v| BlindIndex.generate_bidx(v, **bi) }
            else
              BlindIndex.generate_bidx(value, **bi)
            end
        end

        super(attribute, value, operator)
      end
    end

    module UniquenessValidator
      def validate_each(record, attribute, value)
        klass = record.class
        if klass.respond_to?(:blind_indexes) && (bi = klass.blind_indexes[attribute])
          value = record.read_attribute_for_validation(bi[:bidx_attribute])
        end
        super(record, attribute, value)
      end

      # change attribute name here instead of validate_each for better error message
      if ActiveRecord::VERSION::STRING >= "5.2"
        def build_relation(klass, attribute, value)
          if klass.respond_to?(:blind_indexes) && (bi = klass.blind_indexes[attribute])
            attribute = bi[:bidx_attribute]
          end
          super(klass, attribute, value)
        end
      else
        def build_relation(klass, table, attribute, value)
          if klass.respond_to?(:blind_indexes) && (bi = klass.blind_indexes[attribute])
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
