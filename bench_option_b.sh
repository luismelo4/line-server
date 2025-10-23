#!/bin/bash
# Benchmark script for Option B (Absolute Offsets) implementation
# Usage: ./bench_option_b.sh <file> [workers] [runs]
# Example: ./bench_option_b.sh random_1gb.txt 4 10

FILE="$1"
WORKERS="${2:-4}"
RUNS="${3:-10}"

if [ -z "$FILE" ]; then
    echo "Usage: $0 <file> [workers] [runs]"
    echo "Example: $0 random_1gb.txt 4 10"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File '$FILE' not found"
    exit 1
fi

echo "Benchmarking Option B implementation"
echo "File: $FILE"
echo "Workers: $WORKERS"
echo "Runs: $RUNS"
echo "Indexer: build_index_parallel.rb (Option B)"
echo ""

# Remove existing index file
rm -f "${FILE}.idx"

# Run benchmarks
for i in $(seq 1 $RUNS); do
    echo -n "Run $i: "
    
    # Time the index building
    start_time=$(date +%s%3N)
    ruby build_index_parallel.rb "$FILE" "$WORKERS" > /dev/null 2>&1
    end_time=$(date +%s%3N)
    
    duration=$((end_time - start_time))
    echo "${duration} ms"
    
    # Verify index was created
    if [ ! -f "${FILE}.idx" ]; then
        echo "Error: Index file not created for run $i"
        exit 1
    fi
    
    # Clean up for next run
    rm -f "${FILE}.idx"
done

echo ""
echo "Benchmark completed!"

