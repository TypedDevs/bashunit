#!/usr/bin/env bash

# The return-slot pattern (`_BASHUNIT_<PKG>_<FN>_OUT` globals) exists to avoid a
# fork per call. It only works when the helper runs in the CALLER's shell: wrap
# it in `$( )` and the assignment happens in a subshell that exits immediately,
# so the caller reads the previous value -- silently, with no error anywhere.
#
# That boundary has produced real bugs in the runner (#1145, #1147) and cost a
# cycle again while fixing the coverage gate (#1171), where `pct=$(…)` threw
# away the totals the gate needed. Nothing catches it at runtime, so catch it
# here.

function set_up_before_script() {
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
}

# Names of functions that assign a `_BASHUNIT_*_OUT` slot inside their body.
#
# Indentation is what distinguishes an assignment in a body from the file-scope
# declaration of the slot itself; a `}` in column 0 ends the function. Both are
# house style everywhere in src/, and getting this wrong reports the declaring
# file's next function instead of the real one.
function _slot_setting_functions() { # $1 = dir to scan
  find "$1" -name '*.sh' -print0 | xargs -0 awk '
    FNR == 1 { fn = "" }
    /^function [A-Za-z0-9_:]+\(\)/ {
      fn = $2
      sub(/\(\).*/, "", fn)
      next
    }
    /^\}/ { fn = ""; next }
    fn != "" && /^[[:space:]]+_BASHUNIT_[A-Za-z0-9_]*_OUT=/ { print fn }
  ' | sort -u
}

# Those of them that some call site wraps in a command substitution.
function _slot_setters_called_in_subshell() { # $1 = dir to scan
  local fn
  local sources
  sources=$(find "$1" -name '*.sh' -print0 | xargs -0 cat)

  while IFS= read -r fn; do
    [ -z "$fn" ] && continue
    case "$sources" in
    *"\$($fn"* | *"\$( $fn"*) printf '%s\n' "$fn" ;;
    esac
  done <<EOF
$(_slot_setting_functions "$1")
EOF
}

function test_no_return_slot_helper_is_called_inside_a_command_substitution() {
  local offenders
  offenders=$(_slot_setters_called_in_subshell "$ROOT_DIR/src")

  assert_empty "$offenders"
}

# A check that cannot fail proves nothing: the tree is expected to be clean, so
# without this the test above would keep passing if the scan silently stopped
# matching.
function test_the_scan_flags_a_helper_that_is_called_in_a_subshell() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' '_BASHUNIT_PROBE_OUT=""'
    printf '%s\n' 'function bashunit::probe::set_it() {'
    printf '%s\n' '  _BASHUNIT_PROBE_OUT="value"'
    printf '%s\n' '  echo "$_BASHUNIT_PROBE_OUT"'
    printf '%s\n' '}'
    printf '%s\n' 'function bashunit::probe::read_it() {'
    printf '%s\n' '  local x'
    printf '%s\n' '  x=$(bashunit::probe::set_it)'
    printf '%s\n' '  echo "$x$_BASHUNIT_PROBE_OUT"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_same "bashunit::probe::set_it" "$(_slot_setters_called_in_subshell "$dir")"
}

# The scan must not report a helper that is only ever called directly, which is
# the whole of src/ today.
function test_the_scan_ignores_a_helper_called_in_the_callers_shell() {
  local dir
  dir="$(bashunit::temp_dir)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' '_BASHUNIT_PROBE_OUT=""'
    printf '%s\n' 'function bashunit::probe::set_it() {'
    printf '%s\n' '  _BASHUNIT_PROBE_OUT="value"'
    printf '%s\n' '}'
    printf '%s\n' 'function bashunit::probe::read_it() {'
    printf '%s\n' '  bashunit::probe::set_it'
    printf '%s\n' '  echo "$_BASHUNIT_PROBE_OUT"'
    printf '%s\n' '}'
  } >"$dir/probe.sh"

  assert_empty "$(_slot_setters_called_in_subshell "$dir")"
}
