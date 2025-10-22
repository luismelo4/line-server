# spec/spec_helper.rb
ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'
require 'tempfile'
require 'fileutils'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  # Use color output
  config.color = true
  
  # Use documentation format for output
  config.formatter = :documentation
  
  # Filter backtrace
  config.backtrace_exclusion_patterns << /gems/
end

# Helper to create a test file with known content
def create_test_file(lines)
  file = Tempfile.new(['test_file', '.txt'])
  lines.each { |line| file.puts(line) }
  file.close
  file
end

# Helper to build index for a test file
def build_index(text_file_path)
  require_relative '../build_index'
  index_path = "#{text_file_path}.idx"
  
  File.open(text_file_path, "rb") do |tf|
    File.open(index_path, "wb") do |idx|
      offset = 0
      while (line = tf.gets)
        idx.write([offset].pack("Q<"))
        offset = tf.pos
      end
    end
  end
  
  index_path
end

