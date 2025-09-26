#!/usr/bin/env bash

function doc::print_asserts() {
  local filter="${1:-}"
  local doc_file="$BASHUNIT_ROOT_DIR/docs/assertions.md"
  local line
  local docstring=""
  local fn=""
  local should_print=0

  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^##\ ([A-Za-z0-9_]+) ]]; then
      fn="${BASH_REMATCH[1]}"
      if [[ -z "$filter" || "$fn" == *"$filter"* ]]; then
        should_print=1
        echo "$line"
        docstring=""
      else
        should_print=0
      fi
      continue
    fi

    if (( should_print )); then
      if [[ "$line" =~ ^\`\`\` ]]; then
        echo "--------------"
        echo "$docstring"
        should_print=0
        continue
      fi

      [[ "$line" == "::: code-group" ]] && continue

      # Remove markdown link brackets and anchor tags
      line="${line//[\[\]]/}"
      line="$(sed -E 's/ *\(#[-a-z0-9]+\)//g' <<< "$line")"
      docstring+="$line"$'\n'
    fi
  done < "$doc_file"
}
