module BlindIndex
  module Model
    def blind_index(*attributes, rotate: false, migrating: false, **opts)
      indexes = attributes.map { |a| [a, opts.dup] }
      indexes.concat(attributes.map { |a| [a, rotate.merge(rotate: true)] }) if rotate

      indexes.each do |name, options|
        rotate = options.delete(:rotate)

        # check here so we validate rotate options as well
        unknown_keywords = options.keys - [:algorithm, :attribute, :bidx_attribute,
          :callback, :cost, :encode, :expression, :insecure_key, :iterations, :key,
          :legacy, :master_key, :size, :slow, :version]
        raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?

        attribute = options[:attribute] || name
        version = (options[:version] || 1).to_i
        callback = options[:callback].nil? ? true : options[:callback]
        if options[:bidx_attribute]
          bidx_attribute = options[:bidx_attribute]
        else
          bidx_attribute = name
          bidx_attribute = "encrypted_#{bidx_attribute}" if options[:legacy]
          bidx_attribute = "#{bidx_attribute}_bidx"
          bidx_attribute = "#{bidx_attribute}_v#{version}" if version != 1
        end

        name = "migrated_#{name}" if migrating
        name = "rotated_#{name}" if rotate
        name = name.to_sym
        attribute = attribute.to_sym
        method_name = :"compute_#{name}_bidx"
        class_method_name = :"generate_#{name}_bidx"

        key = options[:key]
        key ||= -> { BlindIndex.index_key(table: try(:table_name) || collection_name.to_s, bidx_attribute: bidx_attribute, master_key: options[:master_key], encode: false) }

        class_eval do
          activerecord = defined?(ActiveRecord) && self < ActiveRecord::Base

          if activerecord && ActiveRecord::VERSION::MAJOR >= 6
            # blind index value isn't really sensitive
            # but don't need to show it in the Rails console
            self.filter_attributes += [/\A#{Regexp.escape(bidx_attribute)}\z/]
          end

          @blind_indexes ||= {}

          unless respond_to?(:blind_indexes)
            def self.blind_indexes
              parent_indexes =
                if superclass.respond_to?(:blind_indexes)
                  superclass.blind_indexes
                else
                  {}
                end

              parent_indexes.merge(@blind_indexes || {})
            end
          end

          raise BlindIndex::Error, "Duplicate blind index: #{name}" if blind_indexes[name]

          @blind_indexes[name] = options.merge(
            key: key,
            attribute: attribute,
            bidx_attribute: bidx_attribute,
            migrating: migrating
          )

          define_singleton_method class_method_name do |value|
            BlindIndex.generate_bidx(value, **blind_indexes[name])
          end

          define_method method_name do
            send("#{bidx_attribute}=", self.class.send(class_method_name, send(attribute)))
          end

          if callback
            # TODO reuse module
            m = Module.new do
              define_method "#{attribute}=" do |value|
                result = super(value)
                send(method_name)
                result
              end

              unless activerecord
                define_method "reset_#{attribute}!" do
                  result = super()
                  send(method_name)
                  result
                end
              end
            end
            prepend m
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
end
