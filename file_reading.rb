require 'stringex'

module FileReading
  # Opens the file and executes the block for every line in the file.
  # The line is converted to valid UTF-8 before being passed to the block.
  #
  # If to_ascii is true, the Unicode characters in each line are transliterated
  # to ASCII approximation.
  #
  # If no block is given, an enumerator is returned instead.
  def each_line_in_file(path, to_ascii: false, possible_encodings: [])
    return enum_for(:each_line_in_file, path,
                    to_ascii:           to_ascii,
                    possible_encodings: possible_encodings) unless block_given?

    # Force intepreting the bytes read from the file as UTF-8
    # instead of relying on the default external encoding being UTF-8
    File.open(path, external_encoding: Encoding::UTF_8).each_line do |line|
      convert_to_valid_utf8!(line, possible_encodings)

      yield(to_ascii && !line.ascii_only? ? line.to_ascii : line)
    end
  end
  module_function :each_line_in_file

  # Does an in-place conversion of the string to valid UTF-8.
  # Returns a string with encoding set to UTF-8 and a valid UTF-8 byte sequence.
  #
  # Does not modify the byte sequence if the string is already valid UTF-8.
  # If not already valid UTF-8, attempts to transcode the string from every
  # encoding in possible_encodings to UTF-8 until the string is valid UTF-8.
  #
  # If the string is still not valid UTF-8 after this, all the invalid
  # and undefined bytes will be stripped out.
  def convert_to_valid_utf8!(string, possible_encodings = [])
    original_encoding = string.encoding
    string.force_encoding(Encoding::UTF_8) if original_encoding == Encoding::BINARY
    return string if string.encoding == Encoding::UTF_8 && string.valid_encoding?

    possible_encodings.each do |encoding|
      string.force_encoding(encoding)
      return string.encode!(Encoding::UTF_8) if string.valid_encoding?
    end

    # Strip out remaining invalid/undefind characters as a last resort
    string.encode!(Encoding::UTF_8, original_encoding, invalid: :replace, undef: :replace, replace: '')
  end
  module_function :convert_to_valid_utf8!
end
