#!/usr/bin/env bash

# This function returns the embedded assertions.md content.
# During development, it reads from the file.
# During build, this function is replaced with actual content.
function bashunit::doc::get_embedded_docs() {
  # __BASHUNIT_EMBEDDED_DOCS_START__
  cat "$BASHUNIT_ROOT_DIR/docs/assertions.md"
  # __BASHUNIT_EMBEDDED_DOCS_END__
}

# Single awk pass over the embedded docs: the previous line-by-line shell loop
# forked an `echo | sed` pipe per line (~3.2k forks, ~5s for the ~1.6k-line
# docs page); one awk fork does the same work in milliseconds (#832).
function bashunit::doc::print_asserts() {
  local filter="${1:-}"

  bashunit::doc::get_embedded_docs | awk -v filter="$filter" '
    {
      if ($0 ~ /^## /) {
        # Heading word: the leading [A-Za-z0-9_]* run after "## ". Only
        # assert*/bashunit* headings are doc entries; prose headings like
        # "## Related" fall through and are treated as regular content.
        fn = substr($0, 4)
        sub(/[^A-Za-z0-9_].*$/, "", fn)
        if (fn ~ /^(assert|bashunit)/) {
          if (filter == "" || index(fn, filter) > 0) {
            should_print = 1
            print $0
            doc = ""
          } else {
            should_print = 0
          }
          next
        }
      }

      if (should_print) {
        if ($0 ~ /^```/) {
          print "--------------"
          print doc
          should_print = 0
          next
        }
        if ($0 ~ /^::: code-group/) next

        # Remove markdown link brackets and anchor tags
        line = $0
        gsub(/[\[\]]/, "", line)
        gsub(/ *\(#[-a-z0-9]+\)/, "", line)
        doc = doc line "\n"
      }
    }
  '
}
