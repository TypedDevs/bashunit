#!/usr/bin/env bash

# Print a single rounded coverage percentage (integer, no % sign) read from an
# LCOV report. It sums the per-section LH (lines hit) and LF (lines found)
# records and rounds LH/LF to the nearest integer. Prints 0 when the report is
# missing, empty, or records no lines. Used by the coverage CI workflow to feed
# a shields.io endpoint badge.
#
# Usage: coverage_percent.sh <path-to-lcov.info>

set -eu

lcov_file="${1:-}"

if [ -z "$lcov_file" ] || [ ! -f "$lcov_file" ]; then
  echo 0
  exit 0
fi

awk -F: '
  /^LH:/ { hit += $2 }
  /^LF:/ { found += $2 }
  END {
    if (found <= 0) { print 0; exit }
    printf "%d\n", (hit * 100 + found / 2) / found
  }
' "$lcov_file"
