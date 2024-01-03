require 'amazing_print'

module Cisqua
  class ErrorFormatter
    def initialize(err)
      @e = err
    end

    def formatted
      formatted_impl(@e).join("\n")
    end

    def formatted_impl(e)
      first_line = AmazingPrint::Colors.red(
        "#{e.backtrace.first}: #{e.message} (#{e.class})",
      )
      rest = e.backtrace[1..].map do |l|
        AmazingPrint::Colors.red("\tfrom #{l}")
      end

      if e.cause
        rest += formatted_impl(e.cause)
      end

      rest.unshift(first_line)
    end
  end
end
