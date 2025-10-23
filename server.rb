# server.rb
require "sinatra"
require_relative "offset_index"

INDEX_PATH = ENV["INDEX_FILE"]
TEXT_FILE  = ENV["TEXT_FILE"]

abort("TEXT_FILE or INDEX_FILE not set") unless INDEX_PATH && TEXT_FILE

OFFSET_INDEX = OffsetIndex.new(INDEX_PATH)
puts "Loaded offset index: #{INDEX_PATH} (#{OFFSET_INDEX.total_lines} lines)"

get "/lines/:id" do
  line_num = params[:id].to_i

  begin
    offset = OFFSET_INDEX.offset_for(line_num)
  rescue IndexError
    halt 413, "Line out of range"
  end

  content_type "text/plain"
  File.open(TEXT_FILE, "rb") do |f|
    f.seek(offset)
    f.gets&.chomp || ""
  end
end


