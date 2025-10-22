# spec/offset_index_spec.rb
require_relative 'spec_helper'
require_relative '../offset_index'

RSpec.describe OffsetIndex do
  let(:test_lines) { ["First line", "Second line", "Third line", "Fourth line", "Fifth line"] }
  let(:test_file) { create_test_file(test_lines) }
  let(:index_path) { build_index(test_file.path) }
  
  after do
    File.delete(index_path) if File.exist?(index_path)
    test_file.unlink
  end
  
  describe "#initialize" do
    it "loads the index file" do
      expect { OffsetIndex.new(index_path) }.not_to raise_error
    end
    
    it "raises error if index file doesn't exist" do
      expect { OffsetIndex.new("nonexistent.idx") }.to raise_error(RuntimeError, /Index file not found/)
    end
  end
  
  describe "#total_lines" do
    it "returns the correct number of lines" do
      offset_index = OffsetIndex.new(index_path)
      expect(offset_index.total_lines).to eq(test_lines.length)
    end
  end
  
  describe "#offset_for" do
    let(:offset_index) { OffsetIndex.new(index_path) }
    
    it "returns the correct offset for first line" do
      expect(offset_index.offset_for(0)).to eq(0)
    end
    
    it "returns the correct offset for middle line" do
      offset = offset_index.offset_for(2)
      expect(offset).to be > 0
      
      # Verify the offset points to the correct line
      File.open(test_file.path, "rb") do |f|
        f.seek(offset)
        expect(f.gets.chomp).to eq(test_lines[2])
      end
    end
    
    it "returns the correct offset for last line" do
      offset = offset_index.offset_for(test_lines.length - 1)
      
      File.open(test_file.path, "rb") do |f|
        f.seek(offset)
        expect(f.gets.chomp).to eq(test_lines.last)
      end
    end
    
    it "raises IndexError for negative line numbers" do
      expect { offset_index.offset_for(-1) }.to raise_error(IndexError)
    end
    
    it "raises IndexError for line numbers beyond file end" do
      expect { offset_index.offset_for(test_lines.length) }.to raise_error(IndexError)
      expect { offset_index.offset_for(test_lines.length + 100) }.to raise_error(IndexError)
    end
  end
  
  describe "with empty file" do
    let(:empty_file) { create_test_file([]) }
    let(:empty_index) { build_index(empty_file.path) }
    
    after do
      File.delete(empty_index) if File.exist?(empty_index)
      empty_file.unlink
    end
    
    it "handles empty files correctly" do
      offset_index = OffsetIndex.new(empty_index)
      expect(offset_index.total_lines).to eq(0)
      expect { offset_index.offset_for(0) }.to raise_error(IndexError)
    end
  end
  
  describe "with single line file" do
    let(:single_file) { create_test_file(["Only line"]) }
    let(:single_index) { build_index(single_file.path) }
    
    after do
      File.delete(single_index) if File.exist?(single_index)
      single_file.unlink
    end
    
    it "handles single line files correctly" do
      offset_index = OffsetIndex.new(single_index)
      expect(offset_index.total_lines).to eq(1)
      expect(offset_index.offset_for(0)).to eq(0)
      expect { offset_index.offset_for(1) }.to raise_error(IndexError)
    end
  end
end

