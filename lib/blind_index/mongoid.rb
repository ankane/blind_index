module BlindIndex
  module Mongoid
    module Criteria
      private

      def expr_query(criterion)
        if has_blind_indexes? && criterion.is_a?(Hash)
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
                  value.map { |v| BlindIndex.generate_bidx(v, bi) }
                else
                  BlindIndex.generate_bidx(value, bi)
                end
            end
          end
        end

        super(criterion)
      end

      # memoize for performance
      def has_blind_indexes?
        unless defined?(@has_blind_indexes)
          @has_blind_indexes = klass.respond_to?(:blind_indexes)
        end
        @has_blind_indexes
      end
    end
  end
end
