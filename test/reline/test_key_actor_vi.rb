require_relative 'helper'

class Reline::ViInsertTest < Reline::TestCase
  def setup
    Reline.send(:test_mode)
    @prompt = '> '
    @config = Reline::Config.new
    @config.read_lines(<<~LINES.split(/(?<=\n)/))
      set editing-mode vi
    LINES
    @encoding = Reline.core.encoding
    @line_editor = Reline::LineEditor.new(@config)
    @line_editor.reset(@prompt)
  end

  def editing_mode_label
    @config.instance_variable_get(:@editing_mode_label)
  end

  def teardown
    Reline.test_reset
  end

  def set_line_around_cursor(before, after, mode)
    raise ArgumentError unless mode == :vi_insert || mode == :vi_command

    input_keys("\C-[0dei")
    input_keys(after)
    input_keys("\C-[0i")
    input_keys(before)
    input_keys(before.empty? ? "\C-[" : "\C-[l") if mode == :vi_command
  end

  def test_vi_command_mode
    input_keys("\C-[")
    assert_equal(:vi_command, editing_mode_label)
  end

  def test_vi_command_mode_with_input
    input_keys("abc\C-[")
    assert_equal(:vi_command, editing_mode_label)
    assert_line_around_cursor('ab', 'c')
  end

  def test_vi_insert
    assert_equal(:vi_insert, editing_mode_label)
    input_keys('i')
    assert_line_around_cursor('i', '')
    assert_equal(:vi_insert, editing_mode_label)
    input_keys("\C-[")
    assert_line_around_cursor('', 'i')
    assert_equal(:vi_command, editing_mode_label)
    input_keys('i')
    assert_line_around_cursor('', 'i')
    assert_equal(:vi_insert, editing_mode_label)
  end

  def test_vi_add
    assert_equal(:vi_insert, editing_mode_label)
    input_keys('a')
    assert_line_around_cursor('a', '')
    assert_equal(:vi_insert, editing_mode_label)
    input_keys("\C-[")
    assert_line_around_cursor('', 'a')
    assert_equal(:vi_command, editing_mode_label)
    input_keys('a')
    assert_line_around_cursor('a', '')
    assert_equal(:vi_insert, editing_mode_label)
  end

  def test_vi_insert_at_bol
    input_keys('I')
    assert_line_around_cursor('I', '')
    assert_equal(:vi_insert, editing_mode_label)
    set_line_around_cursor('I12', '345', :vi_command)
    input_keys('I')
    assert_line_around_cursor('', 'I12345')
    assert_equal(:vi_insert, editing_mode_label)
  end

  def test_vi_add_at_eol
    input_keys('A')
    assert_line_around_cursor('A', '')
    assert_equal(:vi_insert, editing_mode_label)
    set_line_around_cursor('A12', '345', :vi_command)
    input_keys('A')
    assert_line_around_cursor('A12345', '')
    assert_equal(:vi_insert, editing_mode_label)
  end

  def test_ed_insert_one
    input_keys('a')
    assert_line_around_cursor('a', '')
  end

  def test_ed_insert_two
    input_keys('ab')
    assert_line_around_cursor('ab', '')
  end

  def test_ed_insert_mbchar_one
    input_keys('か')
    assert_line_around_cursor('か', '')
  end

  def test_ed_insert_mbchar_two
    input_keys('かき')
    assert_line_around_cursor('かき', '')
  end

  def test_ed_insert_for_mbchar_by_plural_code_points
    input_keys("か\u3099")
    assert_line_around_cursor("か\u3099", '')
  end

  def test_ed_insert_for_plural_mbchar_by_plural_code_points
    input_keys("か\u3099き\u3099")
    assert_line_around_cursor("か\u3099き\u3099", '')
  end

  def test_ed_insert_ignore_in_vi_command
    input_keys("\C-[")
    chars_to_be_ignored = "\C-Oあ=".chars
    input_keys(chars_to_be_ignored.join)
    assert_line_around_cursor('', '')
    input_keys(chars_to_be_ignored.map {|c| "5#{c}" }.join)
    assert_line_around_cursor('', '')
    input_keys('iい')
    assert_line_around_cursor("い", '')
  end

  def test_ed_next_char
    set_line_around_cursor('', 'abcdef', :vi_command)
    input_keys('l')
    assert_line_around_cursor('a', 'bcdef')
    input_keys('2l')
    assert_line_around_cursor('abc', 'def')
  end

  def test_ed_prev_char
    set_line_around_cursor('abcde', 'f', :vi_command)
    input_keys('h')
    assert_line_around_cursor('abcd', 'ef')
    input_keys('2h')
    assert_line_around_cursor('ab', 'cdef')
  end

  def test_history
    Reline::HISTORY.concat(%w{abc 123 AAA})
    input_keys("\C-[")
    assert_line_around_cursor('', '')
    input_keys('k')
    assert_line_around_cursor('', 'AAA')
    input_keys('2k')
    assert_line_around_cursor('', 'abc')
    input_keys('j')
    assert_line_around_cursor('', '123')
    input_keys('2j')
    assert_line_around_cursor('', '')
  end

  def test_vi_paste_prev
    set_line_around_cursor('a', 'bcde', :vi_command)
    input_keys('P')
    assert_line_around_cursor('a', 'bcde')
    input_keys('d$')
    assert_line_around_cursor('', 'a')
    input_keys('P')
    assert_line_around_cursor('bcd', 'ea')
    input_keys('2P')
    assert_line_around_cursor('bcdbcdbcd', 'eeea')
  end

  def test_vi_paste_next
    set_line_around_cursor('a', 'bcde', :vi_command)
    input_keys('p')
    assert_line_around_cursor('a', 'bcde')
    input_keys('d$')
    assert_line_around_cursor('', 'a')
    input_keys('p')
    assert_line_around_cursor('abcd', 'e')
    input_keys('2p')
    assert_line_around_cursor('abcdebcdebcd', 'e')
  end

  def test_vi_paste_prev_for_mbchar
    set_line_around_cursor('あ', 'いうえお', :vi_command)
    input_keys('P')
    assert_line_around_cursor('あ', 'いうえお')
    input_keys('d$')
    assert_line_around_cursor('', 'あ')
    input_keys('P')
    assert_line_around_cursor('いうえ', 'おあ')
    input_keys('2P')
    assert_line_around_cursor('いうえいうえいうえ', 'おおおあ')
  end

  def test_vi_paste_next_for_mbchar
    set_line_around_cursor('あ', 'いうえお', :vi_command)
    input_keys('p')
    assert_line_around_cursor('あ', 'いうえお')
    input_keys('d$')
    assert_line_around_cursor('', 'あ')
    input_keys('p')
    assert_line_around_cursor('あいうえ', 'お')
    input_keys('2p')
    assert_line_around_cursor('あいうえおいうえおいうえ', 'お')
  end

  def test_vi_paste_prev_for_mbchar_by_plural_code_points
    set_line_around_cursor("か\u3099", "き\u3099く\u3099け\u3099こ\u3099", :vi_command)
    input_keys('P')
    assert_line_around_cursor("か\u3099", "き\u3099く\u3099け\u3099こ\u3099")
    input_keys('d$')
    assert_line_around_cursor('', "か\u3099")
    input_keys('P')
    assert_line_around_cursor("き\u3099く\u3099け\u3099", "こ\u3099か\u3099")
    input_keys('2P')
    assert_line_around_cursor("き\u3099く\u3099け\u3099き\u3099く\u3099け\u3099き\u3099く\u3099け\u3099", "こ\u3099こ\u3099こ\u3099か\u3099")
  end

  def test_vi_paste_next_for_mbchar_by_plural_code_points
    set_line_around_cursor("か\u3099", "き\u3099く\u3099け\u3099こ\u3099", :vi_command)
    input_keys('p')
    assert_line_around_cursor("か\u3099", "き\u3099く\u3099け\u3099こ\u3099")
    input_keys('d$')
    assert_line_around_cursor('', "か\u3099")
    input_keys('p')
    assert_line_around_cursor("か\u3099き\u3099く\u3099け\u3099", "こ\u3099")
    input_keys('2p')
    assert_line_around_cursor("か\u3099き\u3099く\u3099け\u3099こ\u3099き\u3099く\u3099け\u3099こ\u3099き\u3099く\u3099け\u3099", "こ\u3099")
  end

  def test_vi_prev_next_word
    set_line_around_cursor('', 'aaa b{b}b ccc', :vi_command)
    input_keys('w')
    assert_line_around_cursor('aaa ', 'b{b}b ccc')
    input_keys('w')
    assert_line_around_cursor('aaa b', '{b}b ccc')
    input_keys('w')
    assert_line_around_cursor('aaa b{', 'b}b ccc')
    input_keys('w')
    assert_line_around_cursor('aaa b{b', '}b ccc')
    input_keys('w')
    assert_line_around_cursor('aaa b{b}', 'b ccc')
    input_keys('w')
    assert_line_around_cursor('aaa b{b}b ', 'ccc')
    input_keys('w')
    assert_line_around_cursor('aaa b{b}b cc', 'c')
    input_keys('b')
    assert_line_around_cursor('aaa b{b}b ', 'ccc')
    input_keys('b')
    assert_line_around_cursor('aaa b{b}', 'b ccc')
    input_keys('b')
    assert_line_around_cursor('aaa b{b', '}b ccc')
    input_keys('b')
    assert_line_around_cursor('aaa b{', 'b}b ccc')
    input_keys('b')
    assert_line_around_cursor('aaa b', '{b}b ccc')
    input_keys('b')
    assert_line_around_cursor('aaa ', 'b{b}b ccc')
    input_keys('b')
    assert_line_around_cursor('', 'aaa b{b}b ccc')
    input_keys('3w')
    assert_line_around_cursor('aaa b{', 'b}b ccc')
    input_keys('3w')
    assert_line_around_cursor('aaa b{b}b ', 'ccc')
    input_keys('3w')
    assert_line_around_cursor('aaa b{b}b cc', 'c')
    input_keys('3b')
    assert_line_around_cursor('aaa b{b', '}b ccc')
    input_keys('3b')
    assert_line_around_cursor('aaa ', 'b{b}b ccc')
    input_keys('3b')
    assert_line_around_cursor('', 'aaa b{b}b ccc')
  end

  def test_vi_end_word
    set_line_around_cursor('', 'aaa   b{b}}}b   ccc', :vi_command)
    input_keys('e')
    assert_line_around_cursor('aa', 'a   b{b}}}b   ccc')
    input_keys('e')
    assert_line_around_cursor('aaa   ', 'b{b}}}b   ccc')
    input_keys('e')
    assert_line_around_cursor('aaa   b', '{b}}}b   ccc')
    input_keys('e')
    assert_line_around_cursor('aaa   b{', 'b}}}b   ccc')
    input_keys('e')
    assert_line_around_cursor('aaa   b{b}}', '}b   ccc')
    input_keys('e')
    assert_line_around_cursor('aaa   b{b}}}', 'b   ccc')
    input_keys('e')
    assert_line_around_cursor('aaa   b{b}}}b   cc', 'c')
    input_keys('e')
    assert_line_around_cursor('aaa   b{b}}}b   cc', 'c')
    input_keys('03e')
    assert_line_around_cursor('aaa   b', '{b}}}b   ccc')
    input_keys('3e')
    assert_line_around_cursor('aaa   b{b}}}', 'b   ccc')
    input_keys('3e')
    assert_line_around_cursor('aaa   b{b}}}b   cc', 'c')
  end

  def test_vi_prev_next_big_word
    set_line_around_cursor('', 'aaa b{b}b ccc', :vi_command)
    input_keys('W')
    assert_line_around_cursor('aaa ', 'b{b}b ccc')
    input_keys('W')
    assert_line_around_cursor('aaa b{b}b ', 'ccc')
    input_keys('W')
    assert_line_around_cursor('aaa b{b}b cc', 'c')
    input_keys('B')
    assert_line_around_cursor('aaa b{b}b ', 'ccc')
    input_keys('B')
    assert_line_around_cursor('aaa ', 'b{b}b ccc')
    input_keys('B')
    assert_line_around_cursor('', 'aaa b{b}b ccc')
    input_keys('2W')
    assert_line_around_cursor('aaa b{b}b ', 'ccc')
    input_keys('2W')
    assert_line_around_cursor('aaa b{b}b cc', 'c')
    input_keys('2B')
    assert_line_around_cursor('aaa ', 'b{b}b ccc')
    input_keys('2B')
    assert_line_around_cursor('', 'aaa b{b}b ccc')
  end

  def test_vi_end_big_word
    set_line_around_cursor('', 'aaa   b{b}}}b   ccc', :vi_command)
    input_keys('E')
    assert_line_around_cursor('aa', 'a   b{b}}}b   ccc')
    input_keys('E')
    assert_line_around_cursor('aaa   b{b}}}', 'b   ccc')
    input_keys('E')
    assert_line_around_cursor('aaa   b{b}}}b   cc', 'c')
    input_keys('E')
    assert_line_around_cursor('aaa   b{b}}}b   cc', 'c')
  end

  def test_ed_quoted_insert
    input_keys('ab')
    input_key_by_symbol(:insert_raw_char, char: "\C-a")
    assert_line_around_cursor("ab\C-a", '')
  end

  def test_ed_quoted_insert_with_vi_arg
    input_keys("ab\C-[3")
    input_key_by_symbol(:insert_raw_char, char: "\C-a")
    input_keys('4')
    input_key_by_symbol(:insert_raw_char, char: '1')
    assert_line_around_cursor("a\C-a\C-a\C-a1111", 'b')
  end

  def test_vi_replace_char
    set_line_around_cursor('abc', 'def', :vi_command)
    input_keys('rz')
    assert_line_around_cursor('abc', 'zef')
    input_keys('2rx')
    assert_line_around_cursor('abcxx', 'f')
  end

  def test_vi_replace_char_with_mbchar
    set_line_around_cursor('あ', 'いうえお', :vi_command)
    input_keys('rx')
    assert_line_around_cursor('あ', 'xうえお')
    input_keys('l2ry')
    assert_line_around_cursor('あxyy', 'お')
  end

  def test_vi_next_char
    set_line_around_cursor('', 'abcdef', :vi_command)
    input_keys('fz')
    assert_line_around_cursor('', 'abcdef')
    input_keys('fe')
    assert_line_around_cursor('abcd', 'ef')
  end

  def test_vi_to_next_char
    set_line_around_cursor('', 'abcdef', :vi_command)
    input_keys('tz')
    assert_line_around_cursor('', 'abcdef')
    input_keys('te')
    assert_line_around_cursor('abc', 'def')
  end

  def test_vi_prev_char
    set_line_around_cursor('abcde', 'f', :vi_command)
    input_keys('Fz')
    assert_line_around_cursor('abcde', 'f')
    input_keys('Fa')
    assert_line_around_cursor('', 'abcdef')
  end

  def test_vi_to_prev_char
    set_line_around_cursor('abcde', 'f', :vi_command)
    input_keys('Tz')
    assert_line_around_cursor('abcde', 'f')
    input_keys('Ta')
    assert_line_around_cursor('a', 'bcdef')
  end

  def test_vi_delete_next_char
    set_line_around_cursor('a', 'bc', :vi_command)
    input_keys('x')
    assert_line_around_cursor('a', 'c')
    input_keys('x')
    assert_line_around_cursor('', 'a')
    input_keys('x')
    assert_line_around_cursor('', '')
    input_keys('x')
    assert_line_around_cursor('', '')
  end

  def test_vi_delete_next_char_for_mbchar
    set_line_around_cursor('あ', 'いう', :vi_command)
    input_keys('x')
    assert_line_around_cursor('あ', 'う')
    input_keys('x')
    assert_line_around_cursor('', 'あ')
    input_keys('x')
    assert_line_around_cursor('', '')
    input_keys('x')
    assert_line_around_cursor('', '')
  end

  def test_vi_delete_next_char_for_mbchar_by_plural_code_points
    set_line_around_cursor("か\u3099", "き\u3099く\u3099", :vi_command)
    input_keys('x')
    assert_line_around_cursor("か\u3099", "く\u3099")
    input_keys('x')
    assert_line_around_cursor('', "か\u3099")
    input_keys('x')
    assert_line_around_cursor('', '')
    input_keys('x')
    assert_line_around_cursor('', '')
  end

  def test_vi_delete_prev_char
    input_keys('ab')
    assert_line_around_cursor('ab', '')
    input_keys("\C-h")
    assert_line_around_cursor('a', '')
  end

  def test_vi_delete_prev_char_for_mbchar
    input_keys('かき')
    assert_line_around_cursor('かき', '')
    input_keys("\C-h")
    assert_line_around_cursor('か', '')
  end

  def test_vi_delete_prev_char_for_mbchar_by_plural_code_points
    input_keys("か\u3099き\u3099")
    assert_line_around_cursor("か\u3099き\u3099", '')
    input_keys("\C-h")
    assert_line_around_cursor("か\u3099", '')
  end

  def test_ed_delete_prev_char
    set_line_around_cursor('abcde', 'fg', :vi_command)
    input_keys('X')
    assert_line_around_cursor('abcd', 'fg')
    input_keys('3X')
    assert_line_around_cursor('a', 'fg')
    input_keys('p')
    assert_line_around_cursor('afbc', 'dg')
  end

  def test_ed_delete_prev_word
    input_keys('abc def{bbb}ccc')
    assert_line_around_cursor('abc def{bbb}ccc', '')
    input_keys("\C-w")
    assert_line_around_cursor('abc def{bbb}', '')
    input_keys("\C-w")
    assert_line_around_cursor('abc def{', '')
    input_keys("\C-w")
    assert_line_around_cursor('abc ', '')
    input_keys("\C-w")
    assert_line_around_cursor('', '')
  end

  def test_ed_delete_prev_word_for_mbchar
    input_keys('あいう かきく{さしす}たちつ')
    assert_line_around_cursor('あいう かきく{さしす}たちつ', '')
    input_keys("\C-w")
    assert_line_around_cursor('あいう かきく{さしす}', '')
    input_keys("\C-w")
    assert_line_around_cursor('あいう かきく{', '')
    input_keys("\C-w")
    assert_line_around_cursor('あいう ', '')
    input_keys("\C-w")
    assert_line_around_cursor('', '')
  end

  def test_ed_delete_prev_word_for_mbchar_by_plural_code_points
    input_keys("あいう か\u3099き\u3099く\u3099{さしす}たちつ")
    assert_line_around_cursor("あいう か\u3099き\u3099く\u3099{さしす}たちつ", '')
    input_keys("\C-w")
    assert_line_around_cursor("あいう か\u3099き\u3099く\u3099{さしす}", '')
    input_keys("\C-w")
    assert_line_around_cursor("あいう か\u3099き\u3099く\u3099{", '')
    input_keys("\C-w")
    assert_line_around_cursor('あいう ', '')
    input_keys("\C-w")
    assert_line_around_cursor('', '')
  end

  def test_ed_newline_with_cr
    input_keys('ab')
    assert_line_around_cursor('ab', '')
    refute(@line_editor.finished?)
    input_keys("\C-m")
    assert_line_around_cursor('ab', '')
    assert(@line_editor.finished?)
  end

  def test_ed_newline_with_lf
    input_keys('ab')
    assert_line_around_cursor('ab', '')
    refute(@line_editor.finished?)
    input_keys("\C-j")
    assert_line_around_cursor('ab', '')
    assert(@line_editor.finished?)
  end

  def test_vi_list_or_eof
    input_keys("\C-d") # quit from inputing
    assert_nil(@line_editor.line)
    assert(@line_editor.finished?)
  end

  def test_vi_list_or_eof_with_non_empty_line
    input_keys('ab')
    assert_line_around_cursor('ab', '')
    refute(@line_editor.finished?)
    input_keys("\C-d")
    assert_line_around_cursor('ab', '')
    assert(@line_editor.finished?)
  end

  def test_completion_journey
    @line_editor.completion_proc = proc { |word|
      %w{
        foo_bar
        foo_bar_baz
      }.map { |i|
        i.encode(@encoding)
      }
    }
    input_keys('foo')
    assert_line_around_cursor('foo', '')
    input_keys("\C-n")
    assert_line_around_cursor('foo_bar', '')
    input_keys("\C-n")
    assert_line_around_cursor('foo_bar_baz', '')
    input_keys("\C-n")
    assert_line_around_cursor('foo', '')
    input_keys("\C-n")
    assert_line_around_cursor('foo_bar', '')
    input_keys("_\C-n")
    assert_line_around_cursor('foo_bar_baz', '')
    input_keys("\C-n")
    assert_line_around_cursor('foo_bar_', '')
  end

  def test_completion_journey_reverse
    @line_editor.completion_proc = proc { |word|
      %w{
        foo_bar
        foo_bar_baz
      }.map { |i|
        i.encode(@encoding)
      }
    }
    input_keys('foo')
    assert_line_around_cursor('foo', '')
    input_keys("\C-p")
    assert_line_around_cursor('foo_bar_baz', '')
    input_keys("\C-p")
    assert_line_around_cursor('foo_bar', '')
    input_keys("\C-p")
    assert_line_around_cursor('foo', '')
    input_keys("\C-p")
    assert_line_around_cursor('foo_bar_baz', '')
    input_keys("\C-h\C-p")
    assert_line_around_cursor('foo_bar_baz', '')
    input_keys("\C-p")
    assert_line_around_cursor('foo_bar_ba', '')
  end

  def test_completion_journey_in_middle_of_line
    @line_editor.completion_proc = proc { |word|
      %w{
        foo_bar
        foo_bar_baz
      }.map { |i|
        i.encode(@encoding)
      }
    }
    set_line_around_cursor('abcde fo', ' ABCDE', :vi_insert)
    input_keys("\C-n")
    assert_line_around_cursor('abcde foo_bar', ' ABCDE')
    input_keys("\C-n")
    assert_line_around_cursor('abcde foo_bar_baz', ' ABCDE')
    input_keys("\C-n")
    assert_line_around_cursor('abcde fo', ' ABCDE')
    input_keys("\C-n")
    assert_line_around_cursor('abcde foo_bar', ' ABCDE')
    input_keys("_\C-n")
    assert_line_around_cursor('abcde foo_bar_baz', ' ABCDE')
    input_keys("\C-n")
    assert_line_around_cursor('abcde foo_bar_', ' ABCDE')
    input_keys("\C-n")
    assert_line_around_cursor('abcde foo_bar_baz', ' ABCDE')
  end

  def test_completion
    @line_editor.completion_proc = proc { |word|
      %w{
        foo_bar
        foo_bar_baz
      }.map { |i|
        i.encode(@encoding)
      }
    }
    input_keys('foo')
    assert_line_around_cursor('foo', '')
    input_keys("\C-i")
    assert_line_around_cursor('foo_bar', '')
  end

  def test_autocompletion_with_upward_navigation
    @config.autocompletion = true
    @line_editor.completion_proc = proc { |word|
      %w{
        Readline
        Regexp
        RegexpError
      }.map { |i|
        i.encode(@encoding)
      }
    }
    input_keys('Re')
    assert_line_around_cursor('Re', '')
    input_keys("\C-i", false)
    assert_line_around_cursor('Readline', '')
    input_keys("\C-i", false)
    assert_line_around_cursor('Regexp', '')
    input_key_by_symbol(:completion_journey_up)
    assert_line_around_cursor('Readline', '')
  ensure
    @config.autocompletion = false
  end

  def test_autocompletion_with_upward_navigation_and_menu_complete_backward
    @config.autocompletion = true
    @line_editor.completion_proc = proc { |word|
      %w{
        Readline
        Regexp
        RegexpError
      }.map { |i|
        i.encode(@encoding)
      }
    }
    input_keys('Re')
    assert_line_around_cursor('Re', '')
    input_keys("\C-i", false)
    assert_line_around_cursor('Readline', '')
    input_keys("\C-i", false)
    assert_line_around_cursor('Regexp', '')
    input_key_by_symbol(:menu_complete_backward)
    assert_line_around_cursor('Readline', '')
  ensure
    @config.autocompletion = false
  end

  def test_completion_with_disable_completion
    @config.disable_completion = true
    @line_editor.completion_proc = proc { |word|
      %w{
        foo_bar
        foo_bar_baz
      }.map { |i|
        i.encode(@encoding)
      }
    }
    input_keys('foo')
    assert_line_around_cursor('foo', '')
    input_keys("\C-i")
    assert_line_around_cursor('foo', '')
  end

  def test_vi_first_print
    input_keys("abcde\C-[^")
    assert_line_around_cursor('', 'abcde')
    input_keys("0\C-ki")
    input_keys(" abcde\C-[^")
    assert_line_around_cursor(' ', 'abcde')
    input_keys("0\C-ki")
    input_keys("   abcde  ABCDE  \C-[^")
    assert_line_around_cursor('   ', 'abcde  ABCDE  ')
  end

  def test_ed_move_to_beg
    input_keys("abcde\C-[0")
    assert_line_around_cursor('', 'abcde')
    input_keys("0\C-ki")
    input_keys(" abcde\C-[0")
    assert_line_around_cursor('', ' abcde')
    input_keys("0\C-ki")
    input_keys("   abcde  ABCDE  \C-[0")
    assert_line_around_cursor('', '   abcde  ABCDE  ')
  end

  def test_vi_to_column
    input_keys("a一二三\C-[0")
    input_keys('1|')
    assert_line_around_cursor('', 'a一二三')
    input_keys('2|')
    assert_line_around_cursor('a', '一二三')
    input_keys('3|')
    assert_line_around_cursor('a', '一二三')
    input_keys('4|')
    assert_line_around_cursor('a一', '二三')
    input_keys('9|')
    assert_line_around_cursor('a一二', '三')
  end

  def test_vi_delete_meta
    set_line_around_cursor('aaa bbb ', 'ccc ddd eee', :vi_command)
    input_keys('dw')
    assert_line_around_cursor('aaa bbb ', 'ddd eee')
    input_keys('db')
    assert_line_around_cursor('aaa ', 'ddd eee')
  end

  def test_vi_delete_meta_nothing
    set_line_around_cursor('', 'foo', :vi_command)
    input_keys('dhp')
    assert_line_around_cursor('', 'foo')
  end

  def test_vi_delete_meta_with_vi_next_word_at_eol
    set_line_around_cursor('', 'foo bar', :vi_command)
    input_keys('w')
    assert_line_around_cursor('foo ', 'bar')
    input_keys('w')
    assert_line_around_cursor('foo ba', 'r')
    input_keys('0dw')
    assert_line_around_cursor('', 'bar')
    input_keys('dw')
    assert_line_around_cursor('', '')
  end

  def test_vi_delete_meta_with_vi_next_char
    set_line_around_cursor('aaa bbb ', 'ccc ___ ddd', :vi_command)
    input_keys('df_')
    assert_line_around_cursor('aaa bbb ', '__ ddd')
  end

  def test_vi_delete_meta_with_arg
    set_line_around_cursor('aaa bbb ccc ', 'ddd', :vi_command)
    input_keys('2dl')
    assert_line_around_cursor('aaa bbb ccc ', 'd')
    input_keys('d2h')
    assert_line_around_cursor('aaa bbb cc', 'd')
    input_keys('2d3h')
    assert_line_around_cursor('aaa ', 'd')
    input_keys('dd')
    assert_line_around_cursor('', '')
  end

  def test_vi_change_meta
    set_line_around_cursor('aaa bbb ', 'ccc ddd eee', :vi_command)
    input_keys('cwaiueo')
    assert_line_around_cursor('aaa bbb aiueo', ' ddd eee')
    input_keys("\C-[")
    assert_line_around_cursor('aaa bbb aiue', 'o ddd eee')
    input_keys('cb')
    assert_line_around_cursor('aaa bbb ', 'o ddd eee')
  end

  def test_vi_change_meta_with_vi_next_word
    set_line_around_cursor('foo  ', 'bar  baz', :vi_command)
    input_keys('cwhoge')
    assert_line_around_cursor('foo  hoge', '  baz')
    input_keys("\C-[")
    assert_line_around_cursor('foo  hog', 'e  baz')
  end

  def test_vi_waiting_operator_with_waiting_proc
    set_line_around_cursor('', 'foo foo foo foo foo', :vi_command)
    input_keys('2d3fo')
    assert_line_around_cursor('', ' foo foo')
    input_keys('fo')
    assert_line_around_cursor(' f', 'oo foo')
  end

  def test_waiting_operator_arg_including_zero
    set_line_around_cursor('', 'a111111111111222222222222', :vi_command)
    input_keys('10df1')
    assert_line_around_cursor('', '11222222222222')
    input_keys('d10f2')
    assert_line_around_cursor('', '22')
  end

  def test_vi_waiting_operator_cancel
    set_line_around_cursor('aaa bbb ', 'ccc', :vi_command)
    # dc dy should cancel delete_meta
    input_keys('dch')
    input_keys('dyh')
    # cd cy should cancel change_meta
    input_keys('cdh')
    input_keys('cyh')
    # yd yc should cancel yank_meta
    # P should not paste yanked text because yank_meta is canceled
    input_keys('ydhP')
    input_keys('ychP')
    assert_line_around_cursor('aa', 'a bbb ccc')
  end

  def test_cancel_waiting_with_symbol_key
    set_line_around_cursor('', 'aaa bbb lll', :vi_command)
    # ed_next_char should move cursor right and cancel vi_next_char
    input_keys('f')
    input_key_by_symbol(:ed_next_char, csi: true)
    input_keys('l')
    assert_line_around_cursor('aa', 'a bbb lll')
    # vi_delete_meta + ed_next_char should delete character
    input_keys('d')
    input_key_by_symbol(:ed_next_char, csi: true)
    input_keys('l')
    assert_line_around_cursor('aa ', 'bbb lll')
  end

  def test_unimplemented_vi_command_should_be_no_op
    set_line_around_cursor('a', 'bc', :vi_command)
    input_keys('@')
    assert_line_around_cursor('a', 'bc')
  end

  def test_vi_yank
    set_line_around_cursor('foo ', 'bar', :vi_command)
    input_keys('y3l')
    assert_line_around_cursor('foo ', 'bar')
    input_keys('P')
    assert_line_around_cursor('foo ba', 'rbar')
    input_keys('3h3yhP')
    assert_line_around_cursor('foofo', 'o barbar')
    input_keys('yyP')
    assert_line_around_cursor('foofofoofoo barba', 'ro barbar')
  end

  def test_vi_yank_nothing
    set_line_around_cursor('', 'foo', :vi_command)
    input_keys('yhp')
    assert_line_around_cursor('', 'foo')
  end

  def test_vi_end_word_with_operator
    set_line_around_cursor('', 'foo bar', :vi_command)
    input_keys('de')
    assert_line_around_cursor('', ' bar')
    input_keys('de')
    assert_line_around_cursor('', '')
    input_keys('de')
    assert_line_around_cursor('', '')
  end

  def test_vi_end_big_word_with_operator
    set_line_around_cursor('', 'aaa   b{b}}}b', :vi_command)
    input_keys('dE')
    assert_line_around_cursor('', '   b{b}}}b')
    input_keys('dE')
    assert_line_around_cursor('', '')
    input_keys('dE')
    assert_line_around_cursor('', '')
  end

  def test_vi_next_char_with_operator
    set_line_around_cursor('', 'foo bar', :vi_command)
    input_keys('df ')
    assert_line_around_cursor('', 'bar')
  end

  def test_ed_delete_next_char_at_eol
    set_line_around_cursor('"あ"', '', :vi_insert)
    input_keys("\C-[")
    assert_line_around_cursor('"あ', '"')
    input_keys('xa"')
    assert_line_around_cursor('"あ"', '')
  end

  def test_vi_kill_line_prev
    input_keys("\C-u", false)
    assert_line_around_cursor('', '')
    input_keys('abc')
    assert_line_around_cursor('abc', '')
    input_keys("\C-u", false)
    assert_line_around_cursor('', '')
    input_keys('abc')
    input_keys("\C-[\C-u", false)
    assert_line_around_cursor('', 'c')
    input_keys("\C-u", false)
    assert_line_around_cursor('', 'c')
  end

  def test_vi_change_to_eol
    set_line_around_cursor('abc', 'def', :vi_command)
    input_keys('C')
    assert_line_around_cursor('abc', '')
    input_keys("\C-[0C")
    assert_line_around_cursor('', '')
    assert_equal(:vi_insert, editing_mode_label)
  end

  def test_vi_motion_operators
    assert_equal(:vi_insert, editing_mode_label)

    assert_nothing_raised do
      input_keys("test = { foo: bar }\C-[BBBldt}b")
    end
  end

  def test_emacs_editing_mode
    @line_editor.__send__(:emacs_editing_mode, nil)
    assert(@config.editing_mode_is?(:emacs))
  end
end
