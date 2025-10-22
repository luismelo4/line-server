#!/usr/bin/env bash
set -euo pipefail

FILE=${1:-}
RUNS=${2:-10}
INDEXER=${3:-build_index.rb}

if [ -z "$FILE" ]; then
  echo "Usage: $0 <path-to-text-file> [runs=10] [indexer=build_index.rb]"
  echo "Examples:"
  echo "  $0 data.txt 10                    # Use sequential indexer"
  echo "  $0 data.txt 10 build_index_parallel.rb  # Use parallel indexer"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "File not found: $FILE"
  exit 1
fi

sizes=()
times_ms=()

echo "Benchmarking index build for $FILE over $RUNS runs using $INDEXER..."

for ((i=1; i<=RUNS; i++)); do
  idx_path="${FILE}.idx"
  rm -f "$idx_path"

  start_ns=$(date +%s%N)
  if [ "$INDEXER" = "build_index_parallel.rb" ]; then
    workers="${INDEX_WORKERS:-$(nproc)}"
    ruby "$INDEXER" "$FILE" "$workers" >/dev/null
  else
    ruby "$INDEXER" "$FILE" >/dev/null
  fi
  end_ns=$(date +%s%N)

  # Compute elapsed ms
  elapsed_ns=$((end_ns - start_ns))
  elapsed_ms=$((elapsed_ns / 1000000))
  times_ms+=("$elapsed_ms")

  size_bytes=$(stat -c%s "$idx_path")
  sizes+=("$size_bytes")

  echo "Run $i: ${elapsed_ms}ms, index size ${size_bytes} bytes"
done

# Compute averages
sum_t=0
sum_s=0
for t in "${times_ms[@]}"; do sum_t=$((sum_t + t)); done
for s in "${sizes[@]}"; do sum_s=$((sum_s + s)); done

avg_t=$(awk -v s="$sum_t" -v n="$RUNS" 'BEGIN{printf "%.2f", s/n}')
avg_s=$(awk -v s="$sum_s" -v n="$RUNS" 'BEGIN{printf "%.2f", s/n}')

min_t=${times_ms[0]}
max_t=${times_ms[0]}
for t in "${times_ms[@]}"; do
  if [ "$t" -lt "$min_t" ]; then min_t=$t; fi
  if [ "$t" -gt "$max_t" ]; then max_t=$t; fi
done

echo "---"
echo "Runs: $RUNS"
echo "Avg time: ${avg_t} ms (min ${min_t} ms, max ${max_t} ms)"
echo "Avg index size: ${avg_s} bytes"


