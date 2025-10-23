#!/usr/bin/env bash
# Test runner script for Unix/Linux/Mac
# Runs the RSpec test suite

set -euo pipefail

FORMAT="${1:-documentation}"

echo "Running RSpec test suite..."
echo ""

bundle exec rspec --format "$FORMAT"

echo ""
echo "✅ All tests passed!"

