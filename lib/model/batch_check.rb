require 'active_model'
require_relative 'redisable'

module Cisqua
  class BatchCheck
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :request_source, :batch_data_id
    unique_attrs
    other_required_attrs :request_source

    def batch_data
      BatchData.find(batch_data_id) unless batch_data_id == ''
    end

    def self.find_if_exists
      find_by_
    end

    def self.make_key
      'bc:latest'
    end

    def self.update(attrs)
      instance = find_if_exists || new
      assert(!attrs[:batch_data_id].nil?, 'must explicitly set batch_data to empty to disconnect it')

      batch_data = BatchData.find(attrs[:batch_data_id]) unless attrs[:batch_data_id] == ''
      attrs[:updated_at] = batch_data.updated_at unless batch_data.nil?
      instance.update(attrs)
    end
  end
end
