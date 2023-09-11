require File.expand_path('../../lib/libs', __dir__)
require File.join(Cisqua::ROOT_FOLDER, 'integration_spec', 'test_util')
require 'amazing_print'

# Remove all the data thats meant to be scanned while testing from
# the database. This will allow us to test the system as it typically behaves.
module Cisqua
  class RemoveDataForTesting
    def remove_data
      TestUtil.prep_registry

      scanner = Registry.instance.scanner
      work_item_files = scanner.work_item_files
      work_item_files.each do |w_file|
        size, ed2k = scanner.ed2k_file_hash(w_file.path)
        w_file.size_bytes = size
        w_file.ed2k = ed2k
      end
      TestUtil.data_to_remove_from_redis_as_if_files_never_scanned(
        Registry.instance.redis,
        work_item_files,
        test_mode: false,
      )
    end
  end
end

Cisqua::RemoveDataForTesting.new.remove_data
