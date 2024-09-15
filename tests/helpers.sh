#!/bin/bash
set -euo pipefail

function current_dir() {
  dirname "${BASH_SOURCE[1]}"
}
