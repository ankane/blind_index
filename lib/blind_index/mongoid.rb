module BlindIndex
  module Mongoid
    module Criteria
      private

      def expr_query(criterion)
        if has_blind_indexes? && criterion.is_a?(Hash)
          criterion.keys.each do |key|
            if (bi = klass.blind_indexes[key.to_sym])
              value = criterion.delete(key)
              criterion[bi[:bidx_attribute]] =
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
