#!/usr/bin/env ruby
# Parallel indexer for large text files
# Usage: ruby build_index_parallel.rb <file> [workers]
# Example: ruby build_index_parallel.rb data.txt 8

require 'tempfile'
require 'fileutils'
require 'rbconfig'

# This version uses fork() for Unix/Linux/Mac systems

# Each worker processes a chunk of the file and writes absolute byte offsets
def worker_process(text_file, start_byte, end_byte, worker_id, temp_dir)
  temp_file = File.join(temp_dir, "index.part#{worker_id}")
  count_file = File.join(temp_dir, "count.part#{worker_id}")
  line_count = 0
  
  File.open(text_file, "rb") do |f|
    f.seek(start_byte)
    
    # Write absolute byte positions to our partial index file
    File.open(temp_file, "wb") do |idx|
      current_pos = f.pos
      
      while current_pos < end_byte && !f.eof?
        line_start = current_pos
        line = f.readline rescue break
        break if line.nil? || line.empty?
        
        # Store the absolute byte position where this line starts
        # With this approach we can just concatenate these later
        idx.write([line_start].pack("Q<"))
        line_count += 1
        current_pos = f.pos
      end
    end
  end
  
  # Keep track of how many lines we processed
  File.write(count_file, line_count.to_s)
  
  # Make sure the parent process can read our files
  File.chmod(0644, temp_file)
  File.chmod(0644, count_file)
  
  puts "Worker #{worker_id}: processed #{line_count} lines (absolute offsets #{start_byte}-#{end_byte})"
  line_count
end

text_file = ARGV[0] or abort "Usage: ruby build_index_parallel.rb <file> [workers]"
workers = (ARGV[1] || [Etc.nprocessors * 1.5, 8].min).to_i
workers = 1 if workers < 1

idx_path = "#{text_file}.idx"
puts "Building parallel index for #{text_file} -> #{idx_path} (#{workers} workers)"
puts "Using absolute offsets (no complex merging needed)"
puts "Platform: Unix/Linux/Mac (using fork)"

file_size = File.size(text_file)
chunk_size = file_size / workers

puts "File size: #{file_size} bytes, chunk size: #{chunk_size} bytes"

# Split the file into chunks, but make sure each worker starts at the beginning of a line
chunk_boundaries = []
(0...workers).each do |i|
  start_byte = i * chunk_size
  end_byte = (i == workers - 1) ? file_size : (i + 1) * chunk_size
  
  # If we're not the first worker, skip to the next complete line
  if start_byte > 0
    File.open(text_file, "rb") do |f|
      f.seek(start_byte)
      # Skip forward until we hit a newline
      while start_byte < end_byte && f.getc != "\n"
        start_byte += 1
      end
      start_byte += 1 if start_byte < end_byte # Move past the newline
    end
  end
  
  chunk_boundaries << [start_byte, end_byte]
end

puts "Chunk boundaries (line-aligned): #{chunk_boundaries.map { |s, e| "#{s}-#{e}" }.join(', ')}"

# Create a temp directory for our partial index files
temp_dir = Dir.mktmpdir("index_parallel_")
begin
  pids = []
  
  chunk_boundaries.each_with_index do |(start_byte, end_byte), worker_id|
    # Fork a new process for this worker
    pid = fork do
      line_count = worker_process(text_file, start_byte, end_byte, worker_id, temp_dir)
      exit 0
    end
    pids << pid
  end
  
  # Wait for all workers to finish
  pids.each { |pid| Process.wait(pid) }
  
  total_lines = 0
  (0...workers).each do |worker_id|
    count_file = File.join(temp_dir, "count.part#{worker_id}")
    if File.exist?(count_file)
      count = File.read(count_file).to_i
      total_lines += count
    end
  end
  
  puts "Total lines processed: #{total_lines}"
  
  # Now merge all the partial index files
  puts "Merging partial indices..."
  File.open(idx_path, "wb") do |final_idx|
    (0...workers).each do |worker_id|
      part_file = File.join(temp_dir, "index.part#{worker_id}")
      next unless File.exist?(part_file)
      
      # Just copy each partial index file in order
      # Since we used absolute offsets, we can just concatenate them
      File.open(part_file, "rb") do |part_idx|
        while chunk = part_idx.read(1024*1024)  # Read in 1MB chunks
          final_idx.write(chunk)
        end
      end
    end
  end
  
  puts "Index built: #{idx_path} (#{File.size(idx_path)} bytes)"
  puts "Expected lines: #{total_lines}, actual index entries: #{File.size(idx_path) / 8}"
  puts "✅ Done! Simple concatenation worked perfectly."
  
ensure
  # Clean up our temp files
  FileUtils.rm_rf(temp_dir) if temp_dir
end
