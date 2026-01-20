#!/usr/bin/env bash
set -euo pipefail

# Performance comparison: normal mode vs --no-fork mode
# This script proves that --no-fork is faster than normal mode

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly TEST_FILE="$ROOT_DIR/tests/benchmark/fixtures/no_fork_comparison_test.sh"
readonly ITERATIONS=5

cd "$ROOT_DIR"

echo "=============================================="
echo "Performance Benchmark: Normal vs No-Fork Mode"
echo "=============================================="
echo ""
echo "Test file: $TEST_FILE"
echo "Iterations: $ITERATIONS"
echo ""

# Warm up
echo "Warming up..."
./bashunit "$TEST_FILE" -s >/dev/null 2>&1
./bashunit "$TEST_FILE" -s --no-fork >/dev/null 2>&1
echo ""

# Benchmark normal mode
echo "Running normal mode benchmark..."
normal_total=0
for i in $(seq 1 $ITERATIONS); do
  start_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
  ./bashunit "$TEST_FILE" -s >/dev/null 2>&1
  end_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
  duration=$((end_time - start_time))
  normal_total=$((normal_total + duration))
  echo "  Run $i: ${duration}ms"
done
normal_avg=$((normal_total / ITERATIONS))
echo "  Average: ${normal_avg}ms"
echo ""

# Benchmark no-fork mode
echo "Running no-fork mode benchmark..."
nofork_total=0
for i in $(seq 1 $ITERATIONS); do
  start_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
  ./bashunit "$TEST_FILE" -s --no-fork >/dev/null 2>&1
  end_time=$(python3 -c 'import time; print(int(time.time() * 1000))')
  duration=$((end_time - start_time))
  nofork_total=$((nofork_total + duration))
  echo "  Run $i: ${duration}ms"
done
nofork_avg=$((nofork_total / ITERATIONS))
echo "  Average: ${nofork_avg}ms"
echo ""

# Results
echo "=============================================="
echo "Results"
echo "=============================================="
echo "Normal mode average:  ${normal_avg}ms"
echo "No-fork mode average: ${nofork_avg}ms"

if [[ $nofork_avg -lt $normal_avg ]]; then
  diff=$((normal_avg - nofork_avg))
  percent=$((diff * 100 / normal_avg))
  echo ""
  echo "✓ No-fork mode is ${diff}ms faster (${percent}% improvement)"
  exit 0
else
  diff=$((nofork_avg - normal_avg))
  echo ""
  echo "✗ No-fork mode is ${diff}ms SLOWER (unexpected!)"
  exit 1
fi
