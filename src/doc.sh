#!/usr/bin/env bash

function doc::print_asserts() {
  local filter="${1:-}"
  local doc_file="$BASHUNIT_ROOT_DIR/docs/assertions.md"
  local line
  local print=0
  local docstring=""
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ ^##\ ([A-Za-z0-9_]+) ]]; then
      local fn="${BASH_REMATCH[1]}"
      if [[ -z "$filter" || "$fn" == *"$filter"* ]]; then
        print=1
        echo "$line"
        docstring=""
      else
        print=0
      fi
      continue
    fi

    if [[ $print -eq 1 ]]; then
      if [[ "$line" =~ ^\`\`\` ]]; then
        print=0
        echo "--------------"
        echo "$docstring"
        continue
      fi
      [[ "$line" == "::: code-group" ]] && continue
      line="${line//[\[\]]/}"
      line="$(sed -E 's/ *\(#[-a-z0-9]+\)//g' <<< "$line")"
      docstring+="$line"$'\n'
    fi
  done < "$doc_file"
}
