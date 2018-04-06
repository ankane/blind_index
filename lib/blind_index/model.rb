module BlindIndex
  module Model
    def blind_index(name, key: nil, iterations: nil, attribute: nil, expression: nil, bidx_attribute: nil, callback: true)
      iterations ||= 10000
      attribute ||= name
      bidx_attribute ||= :"encrypted_#{name}_bidx"

      name = name.to_sym
      attribute = attribute.to_sym
      method_name = :"compute_#{name}_bidx"

      class_eval do
        class << self
          def blind_indexes
            @blind_indexes ||= {}
          end unless respond_to?(:blind_indexes)
        end

        raise BlindIndex::Error, "Duplicate blind index: #{name}" if blind_indexes[name]

        blind_indexes[name] = {
          key: key,
          iterations: iterations,
          attribute: attribute,
          expression: expression,
          bidx_attribute: bidx_attribute
        }

        define_method method_name do
          self.send("#{bidx_attribute}=", BlindIndex.generate_bidx(send(attribute), self.class.blind_indexes[name]))
        end

        if callback
          before_validation method_name, if: -> { changes.key?(attribute.to_s) }
        end
      end
    end
  end
end
