# A record of a particular raw file in a scan and the associated data
#
# @attr [String] name The name and relative path to the file
# @attr [String] fid The AnimeFile that this raw file was identified as
# @attr [String] replaced_fid The AnimeFile that this raw file replaced.
# @attr [String] batch_data_id The batch of files this raw file was a part of.
# @attr [String] reason A hash containing data about why this file replaced another.
# @attr [Symbol] result A symbol telling us the result of processing this raw file
# @attr [Integer] index The index of this RawFile in the batch

require 'active_model'

module Cisqua
  class RawFile
    include Model::Saveable
    include SemanticLogger::Loggable

    string_attrs :name, :fid, :replaced_fid, :batch_data_id
    hash_attrs :reason
    symbol_attrs :result
    int_attrs :index
    index_attrs :batch_data_id, :index

    validate :has_valid_data

    immutably_belongs_to :batch_data, foreign_key: :batch_data_id, id_attribute: :index
    has_one :anime_file, foreign_key: :fid, short_name: :file, one_way: true, can_be_nil: true

    def has_valid_data
      if result.nil? || result == :unknown
        %i[fid replaced_fid reason].each do |attr|
          errors.add(attr, 'invalid without result') unless send(attr).nil?
        end
        return
      end

      errors.add(:result, 'invalid value') unless result.in?(%i[unknown success replacement dup junk])
      errors.add(:fid, 'invalid with result') if fid.nil?
      if result == :replacement
        %i[replaced_fid reason].each do |attr|
          errors.add(attr, 'invalid for replacement') if send(attr).nil?
        end
      else
        %i[replaced_fid reason].each do |attr|
          errors.add(attr, 'invalid for non-replacement') unless send(attr).nil?
        end
      end
    end

    def self.make_key(batch_data_id, index)
      "bd:#{batch_data_id}:raw:#{index}"
    end
  end
end
