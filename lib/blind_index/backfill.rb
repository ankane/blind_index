module BlindIndex
  class Backfill
    def initialize(relation, batch_size:)
      @relation = relation
      @transaction = @relation.respond_to?(:transaction)
      @batch_size = batch_size
    end

    def perform(columns:)
      blind_indexes = @relation.blind_indexes

      # filter columns
      if columns
        columns = columns.map(&:to_s)
        blind_indexes.select! { |_, v| columns.include?(v[:bidx_attribute]) }
        bad_columns = columns - blind_indexes.map { |_, v| v[:bidx_attribute] }
        raise ArgumentError, "Bad column: #{bad_columns.first}" if bad_columns.any?
      end

      # build relation
      base_relation = @relation

      # remove true condition in 0.4.0
      if true || (defined?(ActiveRecord::Base) && base_relation.is_a?(ActiveRecord::Base))
        base_relation = base_relation.unscoped
      end

      relation = base_relation

      if defined?(ActiveRecord::Relation) && base_relation.is_a?(ActiveRecord::Relation)
        attributes = blind_indexes.map { |_, v| v[:bidx_attribute] }
        attributes.each_with_index do |attribute, i|
          relation =
            if i == 0
              relation.where(attribute => nil)
            else
              relation.or(base_relation.where(attribute => nil))
            end
        end
      else
        # TODO add where conditions for Mongoid
      end

      # query
      if relation.respond_to?(:find_in_batches)
        relation.find_in_batches(batch_size: @batch_size) do |records|
          backfill_records(records, blind_indexes: blind_indexes)
        end
      else
        each_batch(relation, batch_size: @batch_size) do |records|
          backfill_records(records, blind_indexes: blind_indexes)
        end
      end
    end

    def backfill_records(records, blind_indexes:)
      # do expensive blind index computation outside of transaction
      records.each do |record|
        blind_indexes.each do |k, v|
          record.send("compute_#{k}_bidx") if !record.send(v[:bidx_attribute])
        end
      end

      records.select! { |r| r.changed? }

      with_transaction do
        records.map { |r| r.save(validate: false) }
      end
    end

    def with_transaction
      if @transaction
        @relation.transaction do
          yield
        end
      else
        yield
      end
    end

    def each_batch(scope, batch_size:)
      # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
      # use cursor for Mongoid
      items = []
      scope.all.each do |item|
        items << item
        if items.length == batch_size
          yield items
          items = []
        end
      end
      yield items if items.any?
    end
  end
end
