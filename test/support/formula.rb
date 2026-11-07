# frozen_string_literal: true

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
    def bottle(*) = nil
    def test(&block) = @test_block = block
  end
end
