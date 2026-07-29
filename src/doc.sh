#!/usr/bin/env bash

# Returns the assertions.md content. In a repo checkout it reads the file;
# build.sh swaps everything between the two marker comments below for a heredoc
# holding the docs verbatim, so the single-file binary needs no docs/ directory.
# The markers are load-bearing: build::embed_docs aborts if either is missing.
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

        # Remove markdown link brackets and anchor tags. The bracket class
        # uses the POSIX []][ idiom: busybox awk (Alpine) rejects
        # backslash-escaped brackets inside a bracket expression.
        line = $0
        gsub(/[][]/, "", line)
        gsub(/ *\(#[-a-z0-9]+\)/, "", line)
        doc = doc line "\n"
      }
    }
  '
}

##
# Collects the assert_* functions a bootstrap defined, i.e. those declared now
# that were not declared before it was sourced, into
# _BASHUNIT_DOC_CUSTOM_FNS_OUT (newline separated, sorted).
#
# Diffing against a snapshot rather than a hardcoded list means the built-in set
# never has to be maintained in two places.
# Arguments: $1 - newline separated assert_* names known before the bootstrap
##
_BASHUNIT_DOC_CUSTOM_FNS_OUT=""

function bashunit::doc::custom_fns_to_slot() {
  local known="$1"
  # Declare and assign separately: bash 3.0 does not expand a compound array
  # assignment attached to `local`.
  local -a found
  found=()
  local count=0
  local fn

  for fn in $(compgen -A function assert_ 2>/dev/null); do
    case "
$known
" in
    *"
$fn
"*) continue ;;
    esac

    # Insertion sort. A project's own assertion list is tiny, so this beats a
    # `sort` fork -- and `LC_ALL=C sort` is banned in src/ because bash 5.3.9 on
    # macOS segfaults on that prefix inside a command substitution (#912).
    local i=$count
    while [ "$i" -gt 0 ] && [ "${found[$((i - 1))]}" \> "$fn" ]; do
      found[i]=${found[$((i - 1))]}
      i=$((i - 1))
    done
    found[i]=$fn
    count=$((count + 1))
  done

  local out=""
  local j=0
  while [ "$j" -lt "$count" ]; do
    out="$out${found[j]}"$'\n'
    j=$((j + 1))
  done

  _BASHUNIT_DOC_CUSTOM_FNS_OUT="${out%$'\n'}"
}

##
# Prints the leading comment block of a function, with the comment markers
# stripped. Silent when the function has no comment or was defined somewhere
# unreadable (e.g. sourced from a process substitution).
# Arguments: $1 - function name
##
function bashunit::doc::print_fn_comment() {
  local fn="$1"

  # extdebug is toggled inside the subshell only: enabling it in the caller's
  # shell clobbers caller state (#808).
  local info
  info="$(
    shopt -s extdebug
    declare -F "$fn"
  )"

  local rest="${info#* }"
  local def_line="${rest%% *}"
  local file="${rest#* }"

  case "$def_line" in
  '' | *[!0-9]*) return 0 ;;
  esac
  [ -n "$file" ] && [ -f "$file" ] || return 0

  # Read the file once into an array; walking backwards needs random access and
  # a per-line `sed -n Np` loop is exactly the quadratic pattern #807 removed.
  local -a lines
  lines=()
  local count=0
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    lines[count]="$line"
    count=$((count + 1))
  done <"$file"

  # Collect the comment run immediately above the definition, then print it in
  # source order.
  local first=$((def_line - 1))
  local i=$((first - 1))
  while [ "$i" -ge 0 ]; do
    case "${lines[i]:-}" in
    '#'*) i=$((i - 1)) ;;
    *) break ;;
    esac
  done

  local j=$((i + 1))
  while [ "$j" -lt "$first" ]; do
    line="${lines[j]:-}"
    # Strip the marker: "## " fences render as blank, "# text" as "text".
    line="${line#\#}"
    line="${line#\#}"
    line="${line# }"
    printf '%s\n' "$line"
    j=$((j + 1))
  done
}

##
# Prints the custom assertions defined by a bootstrap, in the shape
# bashunit::doc::print_asserts already uses.
# Arguments: $1 - optional filter
# Returns: 0 when at least one was printed, 1 when there were none
##
function bashunit::doc::print_custom_asserts() {
  local filter="${1:-}"
  local printed=1
  local fn

  for fn in $_BASHUNIT_DOC_CUSTOM_FNS_OUT; do
    if [ -n "$filter" ]; then
      case "$fn" in
      *"$filter"*) ;;
      *) continue ;;
      esac
    fi

    printf '## %s\n' "$fn"
    printf -- '--------------\n'
    bashunit::doc::print_fn_comment "$fn"
    printf '\n'
    printed=0
  done

  return $printed
}
