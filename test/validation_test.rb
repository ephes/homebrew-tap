# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "yaml"
require_relative "support/formula"
require_relative "support/formula_test_runner"

load File.expand_path("../Formula/jpegli.rb", __dir__)

class ValidationTest < Minitest::Test
  WORKFLOW = YAML.load_file(File.expand_path("../.github/workflows/tests.yml", __dir__)).freeze

  def formula_runner(mode)
    Dir.mktmpdir("jpegli-test") do |directory|
      runner = FormulaTestRunner.new(directory, mode)
      yield runner
    end
  end

  def test_bottle_metadata_does_not_replace_the_smoke_test
    formula = Class.new(Formula) do
      bottle { raise "bottle metadata must not execute in the test harness" }
      test { :smoke }
    end
    assert_equal :smoke, formula.test_block.call
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
    regression = steps.find { |step| step["name"] == "Run regression tests" }
    assert_includes regression.fetch("run"), '"$ruby_bin" "$(brew --repository ephes/tap)/test/validation_test.rb"'
    permissions = WORKFLOW.fetch("jobs").fetch("test-bot").fetch("permissions")
    assert permissions.values.all?("read")
  end

  def test_valid_synthetic_jpeg_decodes
    formula_runner(:synthetic) do |runner|
      runner.run
      assert runner.commands.any? { |command| File.basename(command.first) == "djpeg" }
    end
  end

  def test_real_encoder_round_trip
    formula_runner(:real, &:run)
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
