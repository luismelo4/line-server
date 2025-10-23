#!/usr/bin/env python3
import argparse
import hashlib
import os
import sys


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a large ASCII text file with unique, newline-terminated lines.")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--size-gb", type=float, help="Target size in gigabytes (GB)")
    group.add_argument("--size-bytes", type=int, help="Target size in bytes")
    parser.add_argument("--output", required=True, help="Output file path")
    parser.add_argument("--progress-every", type=int, default=250000,
                        help="Print a progress line every N lines (default: 250k)")
    return parser.parse_args()


def generate(output_path: str, target_bytes: int, progress_every: int) -> None:
    # Use a large buffer to improve throughput
    bytes_written = 0
    line_index = 0
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    with open(output_path, "wb", buffering=1024 * 1024) as f:  # 1 MiB buffer
        while bytes_written < target_bytes:
            # Fixed-length, unique ASCII line: "<i>\t<sha1(i)>\n"
            digest = hashlib.sha1(str(line_index).encode("ascii")).hexdigest()
            line = f"{line_index}\t{digest}\n".encode("ascii")

            # If this write would exceed target by a huge margin, we still write the full line
            # to preserve the invariant: file is a sequence of lines ending with \n.
            f.write(line)
            bytes_written += len(line)
            line_index += 1

            if progress_every > 0 and line_index % progress_every == 0:
                print(f"lines={line_index:,} bytes_written={bytes_written:,}", file=sys.stderr)

    print(f"Wrote ~{bytes_written} bytes to {output_path} with {line_index} lines")


def main() -> None:
    args = parse_args()
    target_bytes = (
        int(args.size_gb * 1024 * 1024 * 1024) if args.size_gb is not None else args.size_bytes
    )
    generate(args.output, target_bytes, args.progress_every)


if __name__ == "__main__":
    main()



