require 'minitest/autorun'
require_relative '../file_reading'

def test_file_path
  File.expand_path('../test_data', __FILE__)
end

def test_file(file_name)
  File.join(test_file_path, file_name)
end
