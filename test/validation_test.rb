require "minitest/autorun"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"
require "yaml"

# Load the formula's actual test block without requiring a Homebrew installation.
class Formula
  class << self
    attr_reader :test_block

    def desc(*) = nil
    def homepage(*) = nil
    def url(*) = nil
    def version(*) = nil
    def license(*) = nil
    def depends_on(*) = nil
    def test(&block) = @test_block = block

    def [](name)
      raise "unexpected dependency: #{name}" unless name == "jpeg-turbo"

      Struct.new(:opt_bin).new(Pathname(ENV.fetch("JPEG_TURBO_BIN")))
    end
  end
end

load File.expand_path("../Formula/jpegli.rb", __dir__)

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

  def system(*args)
    @commands << args.map(&:to_s)
    if args.first == bin/"cjpegli"
      input, output = args[1..2]
      case @mode
      when :truncated
        output.binwrite("\xFF\xD8".b)
        return
      when :black, :wrong_size
        header = @mode == :wrong_size ? "P6\n2 8\n255\n" : "P6\n4 4\n255\n"
        input.binwrite(header + "\0" * 48)
      when :missing
        args[0] = bin/"missing-encoder"
        # Execute the broken install path below and propagate its failure.
        return run_command(*args)
      end
      if @mode == :real
        args[0] = Pathname(ENV.fetch("JPEGLI_BIN"))/"cjpegli"
      else
        args = [Formula["jpeg-turbo"].opt_bin/"cjpeg", "-quality", "100", "-outfile", output, input]
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

class ValidationTest < Minitest::Test
  WORKFLOW = YAML.load_file(File.expand_path("../.github/workflows/tests.yml", __dir__))

  def formula_runner(mode)
    Dir.mktmpdir("jpegli-test") do |directory|
      runner = FormulaTestRunner.new(directory, mode)
      yield runner
    end
  end

  def test_explicit_build_target_covers_every_formula
    formulae = Dir.glob(File.expand_path("../Formula/*.rb", __dir__)).map { |path| File.basename(path) }
    assert_equal ["jpegli.rb"], formulae, "update CI targets when adding a formula"
  end

  def test_pr_and_main_push_run_an_explicit_formula_build
    events = WORKFLOW.fetch("on") { WORKFLOW.fetch(true) }
    assert_includes events.fetch("push").fetch("branches"), "main"
    assert events.key?("pull_request")
    steps = WORKFLOW.fetch("jobs").fetch("test-bot").fetch("steps")
    build = steps.find { |step| step.fetch("run", "").include?("--only-formulae") }
    refute_nil build
    # No event guard: both declared events execute the build, rather than
    # silently skipping branch pushes. An explicit name avoids test-bot's
    # empty changed-formula range on branch events.
    refute build.key?("if"), "formula build must run on both events"
    assert_equal "brew test-bot --only-formulae ephes/tap/jpegli", build.fetch("run")
    permissions = WORKFLOW.fetch("jobs").fetch("test-bot").fetch("permissions")
    assert permissions.values.all? { |value| value == "read" }
  end

  def test_valid_synthetic_jpeg_decodes
    formula_runner(:synthetic) do |runner|
      runner.run
      assert runner.commands.any? { |command| File.basename(command.first) == "djpeg" }
    end
  end

  def test_real_encoder_round_trip
    formula_runner(:real) { |runner| runner.run }
  end

  def test_two_byte_jpeg_is_rejected_by_decoder
    formula_runner(:truncated) do |runner|
      error = assert_raises(RuntimeError) { runner.run }
      assert_match(/djpeg/, error.message)
      assert runner.commands.any? { |command| File.basename(command.first) == "djpeg" }
    end
  end

  def test_wrong_dimensions_are_rejected
    formula_runner(:wrong_size) do |runner|
      assert_raises(Minitest::Assertion) { runner.run }
      assert runner.commands.any? { |command| File.basename(command.first) == "djpeg" }
    end
  end

  def test_decodable_black_output_is_rejected
    formula_runner(:black) do |runner|
      assert_raises(Minitest::Assertion) { runner.run }
      assert runner.commands.any? { |command| File.basename(command.first) == "djpeg" }
    end
  end

  def test_broken_install_path_fails
    formula_runner(:missing) do |runner|
      assert_raises(Errno::ENOENT) { runner.run }
      assert_equal "cjpegli", File.basename(runner.commands.first.first)
    end
  end
end
