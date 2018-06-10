module BlindIndex
  module Model
    def blind_index(name, key: nil, iterations: nil, attribute: nil, expression: nil, bidx_attribute: nil, callback: true, algorithm: nil, insecure_key: nil, encode: nil, cost: nil)
      iterations ||= 10000
      attribute ||= name
      bidx_attribute ||= :"encrypted_#{name}_bidx"

      name = name.to_sym
      attribute = attribute.to_sym
      method_name = :"compute_#{name}_bidx"

      class_eval do
        @blind_indexes ||= {}

        unless respond_to?(:blind_indexes)
          def self.blind_indexes
            parent_indexes =
              if superclass.respond_to?(:blind_indexes)
                superclass.blind_indexes
              else
                {}
              end

            parent_indexes.merge(@blind_indexes)
          end
        end

        raise BlindIndex::Error, "Duplicate blind index: #{name}" if blind_indexes[name]

        @blind_indexes[name] = {
          key: key,
          iterations: iterations,
          attribute: attribute,
          expression: expression,
          bidx_attribute: bidx_attribute,
          algorithm: algorithm,
          insecure_key: insecure_key,
          encode: encode,
          cost: cost
        }.reject { |_, v| v.nil? }

        # should have been named generate_#{name}_bidx
        define_singleton_method method_name do |value|
          BlindIndex.generate_bidx(value, blind_indexes[name])
        end

        define_method method_name do
          self.send("#{bidx_attribute}=", self.class.send(method_name, send(attribute)))
        end

        if callback
          before_validation method_name, if: -> { changes.key?(attribute.to_s) }
        end

        # use include so user can override
        include InstanceMethods if blind_indexes.size == 1
      end
    end
  end

  module InstanceMethods
    def read_attribute_for_validation(key)
      if (bi = self.class.blind_indexes[key])
        send(bi[:attribute])
      else
        super
      end
    end
  end
end
