module BlindIndex
  class Backfill
    attr_reader :blind_indexes

    def initialize(relation, batch_size:, columns:)
      @relation = relation
      @transaction = @relation.respond_to?(:transaction)
      @batch_size = batch_size
      @blind_indexes = @relation.blind_indexes
      filter_columns!(columns) if columns
    end

    def perform
      each_batch do |records|
        backfill_records(records)
      end
    end

    private

    # modify in-place
    def filter_columns!(columns)
      columns = Array(columns).map(&:to_s)
      blind_indexes.select! { |_, v| columns.include?(v[:bidx_attribute].to_s) }
      bad_columns = columns - blind_indexes.map { |_, v| v[:bidx_attribute].to_s }
      raise ArgumentError, "Bad column: #{bad_columns.first}" if bad_columns.any?
    end

    def build_relation
      # build relation
      relation = @relation

      if defined?(ActiveRecord::Base) && relation.is_a?(ActiveRecord::Base)
        relation = relation.unscoped
      end

      # convert from possible class to ActiveRecord::Relation or Mongoid::Criteria
      relation = relation.all

      attributes = blind_indexes.map { |_, v| v[:bidx_attribute] }

      if defined?(ActiveRecord::Relation) && relation.is_a?(ActiveRecord::Relation)
        base_relation = relation.unscoped
        or_relation = relation.unscoped

        attributes.each_with_index do |attribute, i|
          or_relation =
            if i == 0
              base_relation.where(attribute => nil)
            else
              or_relation.or(base_relation.where(attribute => nil))
            end
        end

        relation.merge(or_relation)
      else
        relation.merge(relation.unscoped.or(attributes.map { |a| {a => nil} }))
      end
    end

    def each_batch
      relation = build_relation

      if relation.respond_to?(:find_in_batches)
        relation.find_in_batches(batch_size: @batch_size) do |records|
          yield records
        end
      else
        # https://github.com/karmi/tire/blob/master/lib/tire/model/import.rb
        # use cursor for Mongoid
        records = []
        relation.all.each do |record|
          records << record
          if records.length == @batch_size
            yield records
            records = []
          end
        end
        yield records if records.any?
      end
    end

    def backfill_records(records)
      # do expensive blind index computation outside of transaction
      records.each do |record|
        blind_indexes.each do |k, v|
          record.send("compute_#{k}_bidx") if !record.send(v[:bidx_attribute])
        end
      end

      # don't need to save records that went from nil => nil
      records.select! { |r| r.changed? }

      if records.any?
        with_transaction do
          records.each do |record|
            record.save!(validate: false)
          end
        end
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
  end
end
