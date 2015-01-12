require_relative 'spec_helper'

describe FileReading do
  describe '.each_line_in_file' do
    let(:line) { FileReading.each_line_in_file(path, options).first }

    describe 'with UTF-8 encoded file' do
      let(:path)    { test_file('utf8.txt') }
      let(:options) { {} }

      it 'returns valid UTF-8 lines' do
        line.must_equal 'ümlaut'
        line.encoding.must_equal Encoding::UTF_8
        line.valid_encoding?.must_equal true
      end
    end

    describe 'with ISO-8859-1 encoded file' do
      let(:path)    { test_file('iso8859-1.txt') }
      let(:options) { { possible_encodings: ['ISO-8859-1'] } }

      it 'returns valid UTF8-lines' do
        line.must_equal 'ümlaut'
        line.encoding.must_equal Encoding::UTF_8
        line.valid_encoding?.must_equal true
      end
    end

    describe 'with to_ascii option' do
      let(:options) { { to_ascii: true, possible_encodings: ['ISO-8859-1'] } }
      let(:path)    { test_file('iso8859-1.txt') }

      it 'properly converts to ASCII' do
        line.must_equal 'umlaut'
        line.valid_encoding?.must_equal true
      end
    end
  end
end
