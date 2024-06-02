
module Reline
  class IO
    RESET_COLOR = "\e[0m"

    def self.decide_io_gate
      if ENV['TERM'] == 'dumb'
        Reline::Dumb.new
      else
        require 'reline/io/ansi'

        case RbConfig::CONFIG['host_os']
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
          require 'reline/io/windows'
          io = Reline::Windows.new
          if io.msys_tty?
            Reline::ANSI.new
          else
            io
          end
        else
          if $stdout.tty?
            Reline::ANSI.new
          else
            Reline::Dumb.new
          end
        end
      end
    end

    def dumb?
      false
    end

    def win?
      false
    end

    def reset_color_sequence
      self.class::RESET_COLOR
    end

    def encoding
      raise NotImplementedError
    end

    def read_valid_char(timeout)
      buffer = String.new(encoding: Encoding::ASCII_8BIT)
      while true
        c = getc(buffer.empty? ? Float::INFINITY : timeout)
        return unless c && c != -1

        buffer << c
        s = buffer.dup.force_encoding(encoding)
        return s if s.valid_encoding?
      end
    end
  end
end

require 'reline/io/dumb'
