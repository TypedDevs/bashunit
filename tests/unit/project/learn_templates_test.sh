#!/usr/bin/env bash

# `bashunit learn` writes a starter file for each lesson. Seven of the ten
# templates did not parse: a function body of only TODO comments is a bash
# syntax error, and there were 28 such bodies. A learner who generated the file
# and ran the lesson got
#
#   syntax error near unexpected token `}'
#
# from a file bashunit itself had written -- which says nothing about the
# lesson and is a newcomer's first contact with the tool (#1256).
#
# Templates are heredoc-free string literals, so nothing else checks them:
# ShellCheck sees a string, and no test sourced one. This does.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

# Every `local template='…'` block in the lesson files, NUL-separated so an
# embedded newline does not split one template into several.
#
# awk, not perl: Alpine ships without perl, and the snapshot placeholder tests
# already skip there for that reason -- but template validity does not depend
# on the platform, so this has to run everywhere rather than skip.
#
# The block ends at the first line whose last character is the closing quote.
# That is safe because no line *inside* a template ends in one; the only such
# line in these files sits in the `cat <<'EOF'` lesson text, outside any
# template. Checked against a perl extractor: both find 10 templates and agree
# on which parse.
function _lesson_templates() { # $1 = a lesson file, or a directory of them
  local file
  for file in "$1" "$1"/*.sh; do
    [ -f "$file" ] || continue
    awk '
      index($0, "local template=\047") {
        intpl = 1
        sub(/^.*local template=\047/, "")
      }
      intpl {
        if (substr($0, length($0), 1) == "\047") {
          sub(/\047$/, "")
          print
          printf "%c", 0
          intpl = 0
          next
        }
        print
      }
    ' "$file"
  done
}

function test_every_lesson_template_is_valid_bash() {
  local invalid=""
  local tpl
  local tmp
  tmp="$(bashunit::temp_file)"

  while IFS= read -r -d '' tpl; do
    printf '%s\n' "$tpl" >"$tmp"
    if ! bash -n "$tmp" 2>/dev/null; then
      invalid="$invalid$(printf '%s\n' "$tpl" | "$GREP" -m1 'function' || true) "
    fi
  done < <(_lesson_templates "$ROOT_DIR/src/learn/lessons")

  assert_empty "$invalid"
}

# A check that cannot fail proves nothing: the templates are expected to parse,
# so without this the scan above would keep passing if the extraction silently
# stopped matching.
function test_the_scan_flags_a_template_that_does_not_parse() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function bashunit::learn::lesson_probe() {'
    printf '%s\n' "    local template='#!/usr/bin/env bash"
    printf '%s\n' 'function test_probe() {'
    printf '%s\n' '  # only a comment, which bash rejects'
    printf '%s\n' "}'"
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  local found=false
  local tpl tmp
  tmp="$(bashunit::temp_file)"
  while IFS= read -r -d '' tpl; do
    printf '%s\n' "$tpl" >"$tmp"
    bash -n "$tmp" 2>/dev/null || found=true
  done < <(_lesson_templates "$dir")

  assert_same "true" "$found"
}

# The other half of #1256: a template that parses but has no assertions must not
# complete a lesson. `run_lesson_test` treats exit 0 as success, and a test
# without assertions is risky, which exits 0 unless --fail-on-risky is passed.
function test_the_lesson_runner_fails_a_test_with_no_assertions() {
  assert_file_contains "$ROOT_DIR/src/learn/session.sh" "--fail-on-risky"
}

# Lessons gate on "did the learner use this API", but each template carries the
# API name in its own TODO/Hint comments. A plain grep matched the hint and
# passed before any work was done, which let a learner finish a lesson with an
# unrelated passing assertion (#1258).
#
# Scoped to the gates that name an *assertion*. The others look for
# `function set_up()` or `function data_provider_`, which the template declares
# as a skeleton in code on purpose -- those gates cannot distinguish template
# from solution and are not meant to; the test run carries that signal, and
# --fail-on-risky is what makes an unfilled skeleton fail.
#
# An earlier version asserted the invariant over *every* gate and passed only
# because it stopped after the first file. It would have been false for five of
# them.
function test_no_assertion_gate_is_satisfied_by_its_own_template() {
  local offenders=""
  local file pattern tpl tmp checked=0
  tmp="$(bashunit::temp_file)"

  for file in "$ROOT_DIR"/src/learn/lessons/*.sh; do
    while IFS= read -r pattern; do
      case "$pattern" in
      assert_*) ;;
      *) continue ;;
      esac

      while IFS= read -r -d '' tpl; do
        printf '%s\n' "$tpl" >"$tmp"
        checked=$((checked + 1))
        if [ "$(bashunit::learn::count_in_code "$tmp" "$pattern")" -ne 0 ]; then
          offenders="$offenders$(basename "$file"):$pattern "
        fi
      done < <(_lesson_templates "$file")
    done < <("$GREP" -oE 'count_in_code "\$test_file" "[^"]+"' "$file" |
      sed -E 's/.*"\$test_file" "(.*)"/\1/')
  done

  assert_empty "$offenders"
  # Guards the guard: zero comparisons would make the assertion above vacuous.
  assert_greater_than 0 "$checked"
}

# The helper is what makes that true, so pin it directly: a hint in a comment
# must not count, the same call in code must.
function test_count_in_code_ignores_comments() {
  local f
  f="$(bashunit::temp_file)"
  printf '%s\n' '# Hint: assert_contains "x" "$y"' 'assert_same 1 1' >"$f"

  assert_same "0" "$(bashunit::learn::count_in_code "$f" "assert_contains")"
  assert_same "1" "$(bashunit::learn::count_in_code "$f" "assert_same")"
}
