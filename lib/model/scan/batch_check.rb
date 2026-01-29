# A record of the last time an attempt was made to scan
# for raw files to process.
#
# @attr [String] request_source How the batch_check was requested

require 'active_model'

module Cisqua
  class BatchCheck
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :request_source
    single_instance 'bc'
    required_attrs :request_source

    has_many :batch_datas, redis_key_part: :bds

    def self.instance
      if find_if_exists.nil?
        update(request_source: '')
      end
      find
    end

    def latest(count)
      return [] if count != :all && count.zero?

      base = batch_data_ids.sort_by(&:to_i)
      result = if count == :all || count.negative?
        base
      else
        base.last(count)
      end
      result.reverse.map { |id| BatchData.find(id) }
    end

    def self.update_no_files(request_source:)
      update(request_source:)
    end

    def self.update_new_files(request_source:, **attrs, &block)
      batch_data = nil
      created_at = Time.now
      db_provider.write do |transaction|
        batch_data = BatchData.make(
          transaction:,
          request_source:,
          created_at:,
          updated_at: created_at,
          **attrs,
          &block
        )
        update(
          transaction:,
          request_source:,
          updated_at: created_at,
        )
      end
      batch_data
    end

    def self.update(transaction: nil, **attrs)
      instance = find_if_exists || new(request_source: '')
      instance.update(transaction:, **attrs)
    end
    private_class_method :update
  end
end
