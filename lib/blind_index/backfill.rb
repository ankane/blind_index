module BlindIndex
  class Backfill
    attr_reader :blind_indexes

    def initialize(relation, batch_size:)
      @relation = relation
      @transaction = @relation.respond_to?(:transaction)
      @batch_size = batch_size
      @blind_indexes = @relation.blind_indexes
    end

    def perform(columns:)
      filter_columns(columns) if columns

      relation = build_relation(blind_indexes)
      each_batch(relation) do |records|
        backfill_records(records)
      end
    end

    private

    def filter_columns(columns)
      columns = columns.map(&:to_s)
      # modify in-place
      blind_indexes.select! { |_, v| columns.include?(v[:bidx_attribute]) }
      bad_columns = columns - blind_indexes.map { |_, v| v[:bidx_attribute] }
      raise ArgumentError, "Bad column: #{bad_columns.first}" if bad_columns.any?
    end

    def build_relation(blind_indexes)
      # build relation
      base_relation = @relation

      if defined?(ActiveRecord::Base) && base_relation.is_a?(ActiveRecord::Base)
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

      relation
    end

    def backfill_records(records)
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

    def each_batch(relation)
      if relation.respond_to?(:find_in_batches)
        relation.find_in_batches(batch_size: @batch_size) do |records|
          yield records
        end
      else
        # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
        # use cursor for Mongoid
        items = []
        relation.all.each do |item|
          items << item
          if items.length == @batch_size
            yield items
            items = []
          end
        end
        yield items if items.any?
      end
    end
  end
end
