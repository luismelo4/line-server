#!/usr/bin/env bash
set -euo pipefail

FILE=$1
if [ -z "${FILE:-}" ]; then
  echo "Usage: ./run.sh <path-to-text-file>"
  exit 1
fi

if [ ! -f "${FILE}.idx" ]; then
  # Auto-detect parallel indexing based on file size or explicit setting
  file_size=$(stat -c%s "$FILE")
  use_parallel=""
  
  if [ "$file_size" -gt 2147483648 ] || [ "${USE_PARALLEL_INDEX:-}" = "1" ]; then
    use_parallel="1"
  fi
  
  if [ "$use_parallel" = "1" ]; then
    workers="${INDEX_WORKERS:-$(nproc)}"
    echo "Using parallel indexer with $workers workers (file size: $file_size bytes)"
    ruby build_index_parallel.rb "$FILE" "$workers"
  else
    echo "Using sequential indexer (file size: $file_size bytes)"
    ruby build_index.rb "$FILE"
  fi
fi

export TEXT_FILE="$FILE"
export INDEX_FILE="${FILE}.idx"

# Concurrency settings (override via env):
# PUMA_WORKERS: number of worker processes (default 0 = single process)
# PUMA_THREADS_MIN / PUMA_THREADS_MAX: thread pool size per worker
PUMA_WORKERS="${PUMA_WORKERS:-0}"
PUMA_THREADS_MIN="${PUMA_THREADS_MIN:-4}"
PUMA_THREADS_MAX="${PUMA_THREADS_MAX:-16}"

if [ "$PUMA_WORKERS" -gt 0 ]; then
  exec bundle exec puma -b tcp://0.0.0.0:3000 -w "$PUMA_WORKERS" -t "$PUMA_THREADS_MIN:$PUMA_THREADS_MAX" config.ru
else
  exec bundle exec puma -b tcp://0.0.0.0:3000 -t "$PUMA_THREADS_MIN:$PUMA_THREADS_MAX" config.ru
fi
