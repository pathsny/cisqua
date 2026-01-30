module Cisqua
  module Renamer
    class DuplicateResolver
      include SemanticLogger::Loggable
      class << self
        def extract_clones(original, duplicates)
          clones_of_original, rest = duplicates.partition do |item|
            item.file.id == original.file.id
          end
          rest_uniq = rest.uniq { |i| i.file.id }
          [clones_of_original + rest - rest_uniq, rest_uniq]
        end

        def verify_data(original, duplicates)
          assert(
            duplicates.all? { |d| d.file.aid == original.file.aid },
            'all files must be for the same anime',
          )
          assert(
            duplicates.all? { |d| d.file.eid == original.file.eid },
            'all files must be for the same episode',
          )
          assert(
            duplicates.all? { |d| d.file.gid == original.file.gid },
            'all files must be for the same group',
          )
        end

        def resolve(original, duplicates)
          verify_data(original, duplicates)
          clones, rest = extract_clones(original, duplicates)
          best_rest = rest.max(&method(:compare_items))
          make_result = lambda do |selected, others|
            junk, dups = others.partition { |r| compare_items(selected, r).positive? }
            { junk: clones + junk, keep_current: original == selected, dups:, selected: }
          end

          if best_rest && compare_items(original, best_rest).negative?
            others = rest.dup
            others.delete_at(others.index(best_rest))
            make_result[best_rest, others]
          else
            make_result[original, rest]
          end
        end

        def compare_items(item_1, item_2)
          item_1[:quality] ||= FileQuality.new(item_1.file)
          item_2[:quality] ||= FileQuality.new(item_2.file)
          item_1[:quality] <=> item_2[:quality]
        end
      end
    end
  end
end
