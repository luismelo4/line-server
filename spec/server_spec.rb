# spec/server_spec.rb
require_relative 'spec_helper'
require_relative '../offset_index'

# Mock the environment variables and setup before requiring server
ENV['TEXT_FILE'] = nil
ENV['INDEX_FILE'] = nil

RSpec.describe "Line Server API" do
  let(:test_lines) { ["First line", "Second line", "Third line", "Fourth line", "Fifth line"] }
  let(:test_file) { create_test_file(test_lines) }
  let(:index_path) { build_index(test_file.path) }
  
  before do
    # Set environment variables
    ENV['TEXT_FILE'] = test_file.path
    ENV['INDEX_FILE'] = index_path
    
    # Reload server with new environment
    Object.send(:remove_const, :OFFSET_INDEX) if defined?(OFFSET_INDEX)
    Object.send(:remove_const, :TEXT_FILE) if defined?(TEXT_FILE)
    Object.send(:remove_const, :INDEX_PATH) if defined?(INDEX_PATH)
    load './server.rb'
  end
  
  after do
    File.delete(index_path) if File.exist?(index_path)
    test_file.unlink
  end
  
  def app
    Sinatra::Application
  end
  
  describe "GET /lines/:id" do
    context "with valid line numbers" do
      it "returns status 200 for first line" do
        get '/lines/0'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(test_lines[0])
      end
      
      it "returns status 200 for middle line" do
        get '/lines/2'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(test_lines[2])
      end
      
      it "returns status 200 for last line" do
        get '/lines/4'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(test_lines[4])
      end
      
      it "returns text/plain content type" do
        get '/lines/0'
        expect(last_response.content_type).to include('text/plain')
      end
    end
    
    context "with invalid line numbers" do
      it "returns status 413 for line beyond end of file" do
        get '/lines/5'
        expect(last_response.status).to eq(413)
      end
      
      it "returns status 413 for very large line number" do
        get '/lines/999999'
        expect(last_response.status).to eq(413)
      end
      
      it "returns error message for out of range" do
        get '/lines/5'
        expect(last_response.body).to eq("Line out of range")
      end
    end
    
    context "with edge cases" do
      it "handles line number 0 correctly" do
        get '/lines/0'
        expect(last_response.status).to eq(200)
        expect(last_response.body).to eq(test_lines[0])
      end
      
      it "returns 413 for negative line numbers (treated as invalid by to_i)" do
        # Ruby's to_i will convert "-1" to -1, which will cause IndexError
        get '/lines/-1'
        expect(last_response.status).to eq(413)
      end
    end
  end
  
  describe "GET other routes" do
    it "returns 404 for undefined routes" do
      get '/'
      expect(last_response.status).to eq(404)
    end
    
    it "returns 404 for /lines without id" do
      get '/lines/'
      expect(last_response.status).to eq(404)
    end
  end
end

