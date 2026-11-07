# frozen_string_literal: true

require "fileutils"
require "open3"

class FormulaTestRunner
  include Minitest::Assertions

  attr_accessor :assertions
  attr_reader :testpath, :bin, :commands

  def initialize(directory, mode)
    @assertions = 0
    @testpath = Pathname(directory)
    @bin = testpath/"bin"
    @bin.mkpath
    @mode = mode
    @commands = []
  end

  def formula_opt_bin(name)
    raise "unexpected dependency: #{name}" if name != "jpeg-turbo"

    Pathname(ENV.fetch("JPEG_TURBO_BIN"))
  end

  def system(*args)
    @commands << args.map(&:to_s)
    if args.first == bin/"cjpegli"
      input, output = args[1..2]
      case @mode
      when :truncated
        output.binwrite("\xFF\xD8".b)
        return
      when :black, :wrong_size
        header = (@mode == :wrong_size) ? "P6\n2 8\n255\n" : "P6\n4 4\n255\n"
        input.binwrite(header + ("\0" * 48))
      when :missing
        args[0] = bin/"missing-encoder"
        # Execute the broken install path below and propagate its failure.
        return run_command(*args)
      end
      if @mode == :real
        args[0] = Pathname(ENV.fetch("JPEGLI_BIN"))/"cjpegli"
      else
        args = [formula_opt_bin("jpeg-turbo")/"cjpeg", "-quality", "100", "-outfile", output, input]
      end
    end
    run_command(*args)
  end

  def run_command(*args)
    stdout, stderr, result = Open3.capture3(*args.map(&:to_s))
    raise "command failed: #{args.first}: #{stdout}#{stderr}" unless result.success?
  end

  def run
    instance_eval(&Jpegli.test_block)
  end
end
