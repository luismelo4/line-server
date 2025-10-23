# spec/build_index_spec.rb
require_relative 'spec_helper'
require_relative '../offset_index'

RSpec.describe "Index Building" do
  let(:test_lines) { ["Line 1", "Line 2", "Line 3"] }
  let(:test_file) { create_test_file(test_lines) }
  let(:index_path) { "#{test_file.path}.idx" }
  
  after do
    File.delete(index_path) if File.exist?(index_path)
    test_file.unlink
  end
  
  describe "Sequential indexer" do
    it "creates an index file" do
      system("ruby build_index.rb #{test_file.path}")
      expect(File.exist?(index_path)).to be true
    end
    
    it "creates correct index size (8 bytes per line)" do
      system("ruby build_index.rb #{test_file.path}")
      expect(File.size(index_path)).to eq(test_lines.length * 8)
    end
    
    it "creates index with correct offsets" do
      system("ruby build_index.rb #{test_file.path}")
      
      offset_index = OffsetIndex.new(index_path)
      expect(offset_index.total_lines).to eq(test_lines.length)
      
      # Verify each line can be read using the index
      test_lines.each_with_index do |expected_line, i|
        offset = offset_index.offset_for(i)
        File.open(test_file.path, "rb") do |f|
          f.seek(offset)
          actual_line = f.gets.chomp
          expect(actual_line).to eq(expected_line)
        end
      end
    end
  end
  
  describe "Index format" do
    before do
      system("ruby build_index.rb #{test_file.path}")
    end
    
    it "stores offsets as 8-byte little-endian unsigned integers" do
      offsets = []
      File.open(index_path, "rb") do |f|
        while (data = f.read(8))
          offsets << data.unpack1("Q<")
        end
      end
      
      expect(offsets.length).to eq(test_lines.length)
      expect(offsets.first).to eq(0) # First line always at offset 0
      offsets.each { |offset| expect(offset).to be >= 0 }
    end
  end
  
  describe "Special cases" do
    it "handles empty lines correctly" do
      empty_line_file = create_test_file(["Line 1", "", "Line 3"])
      empty_index = "#{empty_line_file.path}.idx"
      
      system("ruby build_index.rb #{empty_line_file.path}")
      
      offset_index = OffsetIndex.new(empty_index)
      expect(offset_index.total_lines).to eq(3)
      
      # Verify empty line
      offset = offset_index.offset_for(1)
      File.open(empty_line_file.path, "rb") do |f|
        f.seek(offset)
        expect(f.gets.chomp).to eq("")
      end
      
      File.delete(empty_index)
      empty_line_file.unlink
    end
    
    it "handles long lines correctly" do
      long_line = "A" * 10000
      long_line_file = create_test_file(["Short", long_line, "Short again"])
      long_index = "#{long_line_file.path}.idx"
      
      system("ruby build_index.rb #{long_line_file.path}")
      
      offset_index = OffsetIndex.new(long_index)
      offset = offset_index.offset_for(1)
      
      File.open(long_line_file.path, "rb") do |f|
        f.seek(offset)
        expect(f.gets.chomp).to eq(long_line)
      end
      
      File.delete(long_index)
      long_line_file.unlink
    end
  end
end

