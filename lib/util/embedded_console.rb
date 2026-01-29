module Cisqua
  class EmbeddedConsole
    include Singleton
    extend Reloadable

    reloadable_const_define :GREEN, "\e[32m"
    reloadable_const_define :RED, "\e[31m"
    reloadable_const_define :RESET, "\e[0m"
    reloadable_const_define :BASE_PROMPT, "#{GREEN}cisqua#{RESET}"

    def start(prefix = nil, other_locals = {})
      require 'pry'
      require 'amazing_print'
      prompt_prefix = prefix ? " - #{RED}#{prefix}#{RESET}" : ''
      base_prompt = "#{BASE_PROMPT}#{prompt_prefix}"
      main_prompt_proc = proc do |_context, nesting, _|
        "(#{base_prompt})#{nesting.zero? ? '' : nesting}>> "
      end
      wait_prompt_proc = proc do |_context, nesting, _|
        "(#{base_prompt})#{nesting.zero? ? '' : nesting}| "
      end
      Pry.config.hooks.add_hook(:before_session, :custom_header) do |output, binding, _pry|
        output.puts 'Welcome to the Pry console for Cisqua App!'
        output.puts '-----------------------------------------'
        binding.eval 'include Cisqua'
      end
      Pry.config.prompt = Pry::Prompt.new(
        :cisqua,
        'custom prompt for cisqua app',
        [main_prompt_proc, wait_prompt_proc],
      )
      Pry.start(
        nil,
        extra_sticky_locals: {
          reg: Registry.instance,
          red: Registry.instance.redis,
          logger: SemanticLogger['AnidbConsole'],
          **other_locals,
        },
      )
    end
  end
end
