module Renamer
  class NameGenerator
    def initialize(make_name)
      @make_name = make_name
    end

    def generate_name_and_path(info)
      @make_name[info].map { |n| escape(n) }
    end

    private

    # ensure that a name can be used on a filesystem
    def escape(name)
      valid_chars = %w(\w \. \- \[ \] \( \) &).join('')
      invalid_rg = "[^#{valid_chars}\s]"
      name.gsub(Regexp.new("#{invalid_rg}(?![#{valid_chars}])"), '')
          .gsub(Regexp.new("\\s#{invalid_rg}"), ' ')
          .gsub(Regexp.new(invalid_rg), ' ')
          .strip.squeeze(' ')
          .sub(/\.$/, '')
    end
  end
end
