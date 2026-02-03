#!/usr/bin/env bash

# This function returns the embedded assertions.md content.
# During development, it reads from the file.
# During build, this function is replaced with actual content.
function bashunit::doc::get_embedded_docs() {
  # __BASHUNIT_EMBEDDED_DOCS_START__
  cat "$BASHUNIT_ROOT_DIR/docs/assertions.md"
  # __BASHUNIT_EMBEDDED_DOCS_END__
}

function bashunit::doc::print_asserts() {
  local filter="${1:-}"
  local line
  local docstring=""
  local fn=""
  local should_print=0

  # Pattern stored in variable for Bash 3.0 compatibility
  local _doc_pattern='^## ([A-Za-z0-9_]+)'
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if [[ $line =~ $_doc_pattern ]]; then
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

      [[ "$line" == "::: code-group"* ]] && continue

      # Remove markdown link brackets and anchor tags
      line="${line//[\[\]]/}"
      line="$(sed -E 's/ *\(#[-a-z0-9]+\)//g' <<< "$line")"
      docstring="$docstring$line"$'\n'
    fi
  done <<< "$(bashunit::doc::get_embedded_docs)"
}
