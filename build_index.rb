# build_index.rb
# Usage: ruby build_index.rb path/to/data.txt

# Only run if this file is being executed directly (not required)
if __FILE__ == $0
  text_file = ARGV[0] or abort "Usage: ruby build_index.rb <file>"

  idx_path = "#{text_file}.idx"
  puts "Building index for #{text_file} -> #{idx_path}"

  File.open(text_file, "rb") do |tf|
    File.open(idx_path, "wb") do |idx|
      offset = 0
      while (line = tf.gets)
        idx.write([offset].pack("Q<")) # 8-byte little-endian
        offset = tf.pos
      end
    end
  end

  puts "Index built: #{idx_path} (#{File.size(idx_path)} bytes)"
end
