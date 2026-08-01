#!/usr/bin/env bash

# Unified and line-by-line diffs rendered under a failed assertion or snapshot.

##
# Renders a git word-diff of two files, indented, and echoes it. Colorized
# unless --no-color is active. Empty when git is unavailable or files match.
# Shared by the snapshot-failure and multiline assert-failure renderers.
# Arguments: $1 expected file path, $2 actual file path
##
function bashunit::console_results::render_diff() {
  local expected_file=$1
  local actual_file=$2

  if ! bashunit::dependencies::has_git; then
    return 0
  fi

  local color_flag="--color=always"
  if bashunit::env::is_no_color_enabled; then
    color_flag="--color=never"
  fi

  # `git diff` exits non-zero when the files differ; the `|| true` keeps that
  # from tripping `set -e`/`pipefail` under --strict. `tail -n +6` drops git's
  # header lines; `sed` indents the body. `--no-ext-diff` ignores a user's
  # `diff.external`/`GIT_EXTERNAL_DIFF`, which would replace this word-diff.
  git diff --no-index --no-ext-diff --word-diff "$color_flag" \
    "$expected_file" "$actual_file" 2>/dev/null |
    tail -n +6 | sed "s/^/    /" || true
}


##
# Echoes a value's first line, appending an ellipsis when it spans several
# lines. Used to keep the inline quoted value on one line when a diff follows.
##
function bashunit::console_results::first_line_ellipsis() {
  local text=$1
  local first="${text%%$'\n'*}"
  if [ "$first" != "$text" ]; then
    printf '%s…' "$first"
  else
    printf '%s' "$text"
  fi
}


##
# Renders a readable line-by-line diff between an expected snapshot and the
# actual content, used as a fallback when git is unavailable. Common lines are
# shown as context, expected-only lines are prefixed with '-' and actual-only
# lines with '+'. Bash 3.0+ compatible (no mapfile, no associative arrays).
# Arguments: $1 expected content, $2 actual content
##
function bashunit::console_results::snapshot_line_diff() {
  local expected=$1
  local actual=$2

  # Explicit empty-array init so referencing the arrays is safe under `set -u`
  # on Bash 4.4+ (Bash 3.x is lenient; newer Bash treats an unset array as unbound).
  # Declare and assign separately: bash 3.0 does not expand a compound array
  # assignment attached to `local`, it stores the literal "()" as element 0.
  local expected_lines actual_lines
  expected_lines=()
  actual_lines=()
  local _line=""
  local i=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    expected_lines[i]=$_line
    i=$((i + 1))
  done <<EOF
$expected
EOF
  local expected_count=$i

  i=0
  while IFS= read -r _line || [ -n "$_line" ]; do
    actual_lines[i]=$_line
    i=$((i + 1))
  done <<EOF
$actual
EOF
  local actual_count=$i

  local max=$expected_count
  if [ "$actual_count" -gt "$max" ]; then
    max=$actual_count
  fi

  local out=""
  i=0
  while [ "$i" -lt "$max" ]; do
    local e="" a="" has_e=0 has_a=0
    if [ "$i" -lt "$expected_count" ]; then
      e=${expected_lines[i]:-}
      has_e=1
    fi
    if [ "$i" -lt "$actual_count" ]; then
      a=${actual_lines[i]:-}
      has_a=1
    fi

    if [ "$has_e" = 1 ] && [ "$has_a" = 1 ] && [ "$e" = "$a" ]; then
      out="$out$(printf "\n    ${_BASHUNIT_COLOR_FAINT}  %s${_BASHUNIT_COLOR_DEFAULT}" "$e")"
    else
      if [ "$has_e" = 1 ]; then
        out="$out$(printf "\n    ${_BASHUNIT_COLOR_FAILED}- %s${_BASHUNIT_COLOR_DEFAULT}" "$e")"
      fi
      if [ "$has_a" = 1 ]; then
        out="$out$(printf "\n    ${_BASHUNIT_COLOR_PASSED}+ %s${_BASHUNIT_COLOR_DEFAULT}" "$a")"
      fi
    fi
    i=$((i + 1))
  done

  printf "%s" "$out"
}

