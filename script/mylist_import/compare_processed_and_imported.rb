require 'redis'
require 'active_support/all'
require 'amazing_print'

module Cisqua
  class ProcessedAndImportedComparer
    attr_reader :red_test, :red_import

    KEYS_WITH_KNOWN_ISSUES = {
      special_ep_count: {
        prefix: ['aid:'],
      },
      highest_episode_number: {
        prefix: ['aid:', 'fid:misc'],
      },
      length: {
        prefix: ['fid:'],
      },
    }.freeze

    def initialize
      @red_test = Redis.new(db: 1)
      @red_import = Redis.new(db: 2)
      @known_issues = {}
    end

    def compare
      missing_keys = red_test.keys.reject { |k| red_import.exists?(k) }
      assert_keys_are_unknown_files(missing_keys)

      (red_test.keys - missing_keys).each do |k|
        data_type = red_test.type(k)

        case data_type
        when 'set'
          compare_set_members(k)
        when 'hash'
          compare_hash_members(k)
        else
          raise "unknown data type #{data_type}"
        end
      end
    end

    def compare_hash_members(k)
      test_data = red_test.hgetall(k).symbolize_keys
      import_data = red_import.hgetall(k).symbolize_keys

      missing_keys = test_data.keys - import_data.keys
      puts "missing keys #{missing_keys} in hash for #{k}" unless missing_keys.empty?
      extra_keys = import_data.keys - test_data.keys
      puts "extra keys #{extra_keys} in hash for #{k}" unless missing_keys.empty?

      hash_keys_which_differ = test_data.keys.select do |h_key|
        test_data_value = test_data[h_key]
        import_data_value = import_data[h_key]
        next false if h_key == :updated_at

        if h_key == :sub_language
          test_data_value = test_data_value.split('\'')[0, 2].join('\'')
        end

        test_data_value != import_data_value
      end

      expected, unexpected = hash_keys_which_differ.partition do |h_key|
        next false unless KEYS_WITH_KNOWN_ISSUES.key?(h_key)

        KEYS_WITH_KNOWN_ISSUES[h_key][:prefix].any? { |p| k.start_with?(p) }
      end

      expected.each do |h_key|
        @known_issues[h_key] = (@known_issues[h_key] || []) << k
      end

      return if unexpected.empty?

      differences = unexpected.each_with_object({}) do |h_key, obj|
        obj[h_key] = {
          test: test_data[h_key],
          import: import_data[h_key],
        }
      end
      ap "hash key differences for key #{k} are #{differences}"
    end

    def compare_set_members(key)
      missing_members = red_test.smembers(key).reject do |member|
        red_import.sismember(key, member)
      end

      return unless missing_members.any?

      puts "missing members for #{key}: #{missing_members}"
    end

    def is_unknown_file(key)
      return false unless red_test.type(key) == 'hash'

      hash_data = red_test.hgetall(key).symbolize_keys
      hash_data.key?(:ed2k) && hash_data[:fid].nil?
    end

    def assert_keys_are_unknown_files(keys)
      known_missing_keys = keys.reject { |key| is_unknown_file(key) }
      return if known_missing_keys.empty?

      puts "known missing keys #{known_missing_keys}"
    end
  end
end

comparer = Cisqua::ProcessedAndImportedComparer.new
comparer.compare
