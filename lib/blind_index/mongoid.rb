module BlindIndex
  module Mongoid
    module Criteria
      private

      def expr_query(criterion)
        if criterion.is_a?(Hash) && klass.respond_to?(:blind_indexes)
          criterion.keys.each do |key|
            key_sym = (key.is_a?(::Mongoid::Criteria::Queryable::Key) ? key.name : key).to_sym

            if (bi = klass.blind_indexes[key_sym])
              value = criterion.delete(key)

              bidx_key =
                if key.is_a?(::Mongoid::Criteria::Queryable::Key)
                  ::Mongoid::Criteria::Queryable::Key.new(
                    bi[:bidx_attribute],
                    key.strategy,
                    key.operator,
                    key.expanded,
                    &key.block
                  )
                else
                  bi[:bidx_attribute]
                end

              criterion[bidx_key] =
                if value.is_a?(Array)
                  value.map { |v| BlindIndex.generate_bidx(v, **bi) }
                else
                  BlindIndex.generate_bidx(value, **bi)
                end
            end
          end
        end

        super(criterion)
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
      def create_criteria(base, document, attribute, value)
        klass = document.class
        if klass.respond_to?(:blind_indexes) && (bi = klass.blind_indexes[attribute])
          attribute = bi[:bidx_attribute]
        end
        super(base, document, attribute, value)
      end
    end
  end
end
