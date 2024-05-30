require_relative 'helper'
require "reline"

class Reline::TestKey < Reline::TestCase
  def test_match_symbol
    assert(Reline::Key.new('a', :key1, false).match?(:key1))
    refute(Reline::Key.new('a', :key1, false).match?(:key2))
    refute(Reline::Key.new('a', :key1, false).match?(nil))
  end

  def test_match_symbol_wrongly_used_in_irb
    refute(Reline::Key.new(nil, 0xE4, true).match?(:foo))
  end
end
