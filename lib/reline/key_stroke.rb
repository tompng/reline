class Reline::KeyStroke
  ESC_BYTE = 27
  CSI_PARAMETER_BYTES_RANGE = 0x30..0x3f
  CSI_INTERMEDIATE_BYTES_RANGE = (0x20..0x2f)

  def initialize(config, encoding)
    @config = config
    @encoding = encoding
  end

  def match_status(input)
    matching = key_mapping.matching?(input)
    matched = key_mapping.get(input)
    if matching && matched
      :matching_matched
    elsif matching
      :matching
    elsif matched
      :matched
    elsif input[0] == ESC_BYTE
      match_unknown_escape_sequence(input, vi_mode: @config.editing_mode_is?(:vi_insert, :vi_command))
    else
      s = input.pack('c*').force_encoding(@encoding)
      if s.valid_encoding?
        s.size == 1 ? :matched : :unmatched
      else
        # Invalid string is :matching (part of valid string) or :matched (invalid bytes to be ignored)
        :matching_matched
      end
    end
  end

  def expand(input)
    matched_bytes = nil
    (1..input.size).each do |i|
      bytes = input.take(i)
      status = match_status(bytes)
      matched_bytes = bytes if status == :matched || status == :matching_matched
      break if status == :matched || status == :unmatched
    end
    return [[], []] unless matched_bytes

    func = key_mapping.get(matched_bytes)
    s = matched_bytes.pack('c*').force_encoding(@encoding)
    if func.is_a?(Array)
      keys = func.map { |c| Reline::Key.new(c.chr(@encoding), :ed_insert, false) }
    elsif func
      keys = [Reline::Key.new(s, func, false)]
    else
      if s.valid_encoding? && s.size == 1
        keys = [Reline::Key.new(s, :ed_insert, false)]
      else
        keys = []
      end
    end

    [keys, input.drop(matched_bytes.size)]
  end

  private

  # returns match status of CSI/SS3 sequence and matched length
  def match_unknown_escape_sequence(input, vi_mode: false)
    idx = 0
    return :unmatched unless input[idx] == ESC_BYTE
    idx += 1
    idx += 1 if input[idx] == ESC_BYTE

    case input[idx]
    when nil
      if idx == 1 # `ESC`
        return :matching_matched
      else # `ESC ESC`
        return :matching
      end
    when 91 # == '['.ord
      # CSI sequence `ESC [ ... char`
      idx += 1
      idx += 1 while idx < input.size && CSI_PARAMETER_BYTES_RANGE.cover?(input[idx])
      idx += 1 while idx < input.size && CSI_INTERMEDIATE_BYTES_RANGE.cover?(input[idx])
    when 79 # == 'O'.ord
      # SS3 sequence `ESC O char`
      idx += 1
    else
      # `ESC char` or `ESC ESC char`
      return :unmatched if vi_mode
    end
    input[idx + 1] ? :unmatched : input[idx] ? :matched : :matching
  end

  def key_mapping
    @config.key_bindings
  end
end
