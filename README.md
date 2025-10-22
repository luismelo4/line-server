# Line Server

A minimal high-performance line server that serves individual lines from a large immutable text file via HTTP.

## API
- GET `/lines/<line index>`: Returns status 200 and the text of the requested line; returns 413 if the requested line is beyond the end of the file.

## How it works

### Building the Index
We have two ways to build the index:

1. **Sequential** (`build_index.rb`): Simple, one worker at a time
2. **Parallel** (`build_index_parallel.rb`): Multiple workers, much faster for big files

Both create an index file (`.idx`) that maps line numbers to byte positions in the original file. Each entry is 8 bytes.

**How the parallel indexer works:**
- Splits the file into chunks (one per worker)
- Each worker processes its chunk and writes byte positions
- Merges everything by just concatenating the partial files
- Uses `fork()` which is super fast on Unix/Linux/Mac

The `run.sh` script automatically uses the parallel indexer for files bigger than 2GB.

### How the Parallel Indexer Works

The parallel indexer splits large files across multiple workers, but there's a tricky problem: what if a line gets split between two workers? We solved this with a simple but effective approach.

#### **The Problem**
When you split a file into chunks, you might cut a line in half:
```
File: "Hello world\nThis is a long line that might get split\nShort line\n"
Split at byte 20: [0-20] and [20-40]

❌ Bad split:
Worker 1: "Hello world\nThis is a long"  ← line cut in half!
Worker 2: "line that might get split\n"   ← starts mid-line!
```

#### **Our Solution: Line Boundary Alignment**
Each worker starts at the beginning of a complete line. If a worker's start position falls in the middle of a line, it skips forward to the next newline:

```
✅ Fixed:
Worker 1: "Hello world\nThis is a long line that might get split\n"
Worker 2: "Short line\n"  ← starts at beginning of next line
```

#### **Why We Use Byte Offsets**
Instead of storing the actual line content, we just store where each line starts (the byte offset). This is much more efficient:

- **Small index**: Only 8 bytes per line, no matter how long the line is
- **Fast lookups**: Jump directly to any line in O(1) time
- **No duplication**: We don't copy the file content, just remember where things are

#### **The Magic of Absolute Offsets**
Each worker writes absolute byte positions from the start of the original file:

```ruby
# If a line starts at byte 1024 in the original file
idx.write([1024].pack("Q<"))  # Store that exact position
```

This means we can just concatenate all the worker results together - no complex merging needed! Each worker's offsets are already in the right order.

#### **Why fork() is Awesome on Unix**
We use `fork()` instead of spawning new processes because:
- **Copy-on-write**: Parent and child share memory until one changes it
- **Super fast**: Much faster than creating new processes from scratch
- **Memory efficient**: No need to copy everything around

#### **Putting It All Together**
The merge step is surprisingly simple - just copy all the partial index files one after another:

```ruby
# Just concatenate everything in order
File.open(idx_path, "wb") do |final_idx|
  (0...workers).each do |worker_id|
    part_file = File.join(temp_dir, "index.part#{worker_id}")
    File.open(part_file, "rb") do |part_idx|
      while chunk = part_idx.read(1024*1024)
        final_idx.write(chunk)
      end
    end
  end
end
```

Since each worker wrote absolute offsets in the correct order, concatenating them gives us a perfect index file.

#### **Performance**
This approach gives us about 2-3x speedup on multi-core systems. The more workers you have, the faster it gets (up to a point - eventually disk I/O becomes the bottleneck).

### Serving Lines
The server (`server.rb`) handles requests:
- Looks up the byte position from the index
- Jumps to that position in the text file and reads the line
- Each request just opens the file and seeks to the right spot
- Multiple people can request lines at the same time

### Handling Lots of Users
Uses Puma web server which can handle many concurrent requests (see the settings section below).

## Build and Run

### Quick Start
```bash
./build.sh                    # Install dependencies
./run.sh path/to/file.txt     # Build index and start server
```

See `LINUX_SETUP.md` for detailed setup instructions.

### Testing the Server
```bash
curl http://127.0.0.1:3000/lines/0      # Get first line
curl http://127.0.0.1:3000/lines/1000   # Get line 1000
```

## Performance
- **Index size**: Only 8 bytes per line (just the positions, not the content)
- **Lookup speed**: Instant to find any line's position, then just read the line
- **What happens per request**: Read the index, jump to the right spot in the file, read the line

### File sizes
- **1 GB**: 
  - Sequential indexer: ~35s
  - Parallel indexer (12 workers): ~19s
  - Index size: ~90 MB (8 bytes per line)
  - Serving: O(1) per request, minimal memory
  
- **10 GB**: 
  - Sequential indexer: ~590s (9.8 minutes)
  - Parallel indexer (12 workers): ~287s (4.8 min)
  - Index size: ~1.6 GB
  - Serving: Same O(1) performance as 1 GB
  
- **100 GB**: 
  - Parallel indexer (12 workers): ~48-64 minutes (estimated)
  - Index size: ~16 GB (for 2B lines)
  - Serving: O(1) lookup with potential memory-mapping for very large indices
  - Recommendation: Use SSD storage and 12-16 workers

See `performance.md` for detailed benchmarks.


## Design Notes
- No database: Only a compact index of offsets, keeping memory usage small.
- ASCII lines; each ends with `\n`; any single line fits in memory.
- Index file `.idx` is immutable once built; server treats the text as read-only.

## Project Structure

### Shell Scripts
- `build.sh`: Installs Ruby gems via Bundler
- `run.sh`: Builds index (if missing) and starts server on port 3000
- `bench_index.sh`: Benchmarks index build performance
- `bench_option_b.sh`: Benchmarks parallel indexer

### Core Files
- `build_index.rb`: Sequential indexer (simple, single-threaded)
- `build_index_parallel.rb`: Parallel indexer (multi-process, Unix/Linux/Mac)
- `offset_index.rb`: Index reader class
- `server.rb`: Sinatra/Puma HTTP server
- `config.ru`: Rack configuration
- `lines_controller.rb`: Controller logic (if used)

### Utilities
- `generate_text_file.py`: Generates test files of specified size

### Test Suite
- `spec/spec_helper.rb`: RSpec configuration and test helpers
- `spec/offset_index_spec.rb`: Tests for OffsetIndex class (10 tests)
- `spec/server_spec.rb`: Tests for HTTP API (11 tests)
- `spec/build_index_spec.rb`: Tests for index building (6 tests)
- `.rspec`: RSpec configuration file

## Documentation & References

### Documentation Consulted
- Sinatra documentation: https://sinatrarb.com/
- Ruby IO documentation: https://ruby-doc.org/core-3.2.0/IO.html
- Puma web server documentation: https://puma.io/
- Ruby Process.fork documentation for Unix process management
- Various StackOverflow discussions on Ruby file I/O performance
- Articles on parallel processing patterns in Ruby

### Third-party Libraries
- **Sinatra** (~3.0): Lightweight web framework, chosen for minimal overhead and simplicity
- **Puma** (~6.0): Multi-threaded web server, chosen for excellent concurrency support
- **RSpec** (~3.12): Testing framework (development/test only)
- **Rack-Test** (~2.1): Testing utilities for Rack apps (development/test only)

All libraries installed via Bundler from rubygems.org.

## Testing

The project includes a comprehensive RSpec test suite covering:
- Index building functionality
- Offset index operations
- HTTP API endpoints
- Edge cases and error handling

### Running Tests
```bash
# Install test dependencies
bundle install

# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/server_spec.rb

# Run with documentation format
bundle exec rspec --format documentation
```

### Test Coverage
- **27 test examples** covering critical functionality
- Tests for sequential indexer
- Tests for OffsetIndex class (initialization, offset lookup, edge cases)
- Tests for HTTP API (valid requests, invalid requests, error handling)
- Tests use temporary files, no cleanup required

## Development Notes

### Time Spent
- Initial implementation (sequential indexer + server): ~3-4 hours
- Parallel indexer development: ~4-5 hours
- Unix/Linux/Mac optimization: ~2 hours
- Testing, benchmarking, and documentation: ~3 hours
- **Total: ~13-15 hours**

### If I Had More Time
Prioritized improvements:

1. **Memory-mapped index files**: For 100GB+ files, mmap the `.idx` file for faster offset lookups
2. **Request-level caching**: LRU cache for frequently accessed lines
3. **CI/CD pipeline**: Automated testing, performance regression detection

### Self-critique

**Strengths:**
- Clean, simple design that scales well
- Unix/Linux/Mac optimized with efficient fork() usage
- Parallel indexer provides significant speedups
- Well-documented with benchmarks
- Handles edge cases properly (line out of range, empty files)

**Areas for Improvement:**
- Index building could be even faster with memory-mapped writes
- No caching layer for hot lines (every request hits disk)
- Error handling could be more robust (disk full, corrupted index)
- No graceful degradation if index file is missing during serving
- Limited observability (no metrics, basic logging)

**Code Quality:**
- Simple, readable Ruby code
- Good separation of concerns (indexing, serving, offset reading)
- Comprehensive test suite (27 tests, 100% passing)
- Well-documented with inline and external documentation
- Tests cover happy path, edge cases, and error conditions


