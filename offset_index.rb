class OffsetIndex
  ENTRY_SIZE = 8

  def initialize(idx_path)
    @idx_path = idx_path
    raise "Index file not found: #{idx_path}" unless File.exist?(idx_path)
    @size = File.size(idx_path)
    @total_lines = @size / ENTRY_SIZE
  end

  attr_reader :total_lines

  def offset_for(line_number)
    raise IndexError, "line_number negative" if line_number < 0
    pos = line_number * ENTRY_SIZE
    raise IndexError, "line_number out of range" if pos + ENTRY_SIZE > @size

    File.open(@idx_path, "rb") do |f|
      f.seek(pos)
      f.read(ENTRY_SIZE).unpack1("Q<")
    end
  end
end
