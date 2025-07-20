#!/usr/bin/env bash

function doc::print_asserts() {
  local search="${1:-}"
  local doc_file="$BASHUNIT_ROOT_DIR/docs/assertions.md"
  local line
  local print=0
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^##\ (assert_[A-Za-z0-9_]+) ]]; then
      local fn="${BASH_REMATCH[1]}"
      if [[ -z "$search" || "$fn" == *"$search"* ]]; then
        print=1
        echo "$line"
      else
        print=0
      fi
      continue
    fi
    if [[ $print -eq 1 ]]; then
      echo "$line"
    fi
  done < "$doc_file"
}
