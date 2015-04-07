module Renamer
class DuplicateResolver
    class << self
      def extract_clones(original, duplicates)
        clones_of_original, rest = duplicates.partition do |item| 
          item.info[:fid] == original.info[:fid]
        end
        rest_uniq = rest.uniq {|item| item.info[:fid] }
        [clones_of_original + rest - rest_uniq, rest_uniq]
      end

      def verify_data(original, duplicates)
        assert(
          duplicates.all? {|i| i.info[:file][:aid] == original.info[:file][:aid]},
          "all files must be for the same anime"
        )
        assert(
          duplicates.all? {|i| i.info[:file][:eid] == original.info[:file][:eid]},
          "all files must be for the same episode"
        )
        assert(
          duplicates.all? {|i| i.info[:file][:gid] == original.info[:file][:gid]},
          "all files must be for the same group"
        )
      end

      def resolve(original, duplicates)
        verify_data(original, duplicates)
        clones, rest = extract_clones(original, duplicates)
        sorted_rest = rest.sort(&method(:compare_items)).reverse

        make_result = lambda do |selected, others|
          junk, dups = others.partition {|r| compare_items(selected, r) > 0}
          {:junk => clones + junk, :keep_current => original == selected, :dups => dups, :selected => selected}
        end  

        if sorted_rest.empty?
          make_result[original, sorted_rest]
        else
          return compare_items(original, sorted_rest.first) < 0 ?
            make_result[sorted_rest.first, sorted_rest.drop(1)] :
            make_result[original, sorted_rest]
        end    
      end

      def compare_items(item_1, item_2)
        item_1.quality <=> item_2.quality
      end
    end
   end  
end