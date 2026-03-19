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
  local docstring=""
  local fn=""
  local should_print=0

  local line
  while IFS='' read -r line || [ -n "$line" ]; do
    fn=$(echo "$line" | sed -n 's/^## \([A-Za-z0-9_]*\).*/\1/p')
    if [ -n "$fn" ]; then
      local _match=0
      if [ -z "$filter" ]; then
        _match=1
      else
        case "$fn" in *"$filter"*) _match=1 ;; esac
      fi
      if [ "$_match" -eq 1 ]; then
        should_print=1
        echo "$line"
        docstring=""
      else
        should_print=0
      fi
      continue
    fi

    if ((should_print)); then
      # Check for code fence using pattern matching instead of regex
      # Avoids backtick escaping issues in Bash 3.0
      case "$line" in
      '```'*)
        echo "--------------"
        echo "$docstring"
        should_print=0
        continue
        ;;
      esac

      case "$line" in
      "::: code-group"*) continue ;;
      esac

      # Remove markdown link brackets and anchor tags
      line="${line//[\[\]]/}"
      line="$(sed -E 's/ *\(#[-a-z0-9]+\)//g' <<<"$line")"
      docstring="$docstring$line"$'\n'
    fi
  done <<<"$(bashunit::doc::get_embedded_docs)"
}
