#!/usr/bin/env bash
set -euo pipefail

# JSON assertions skip the test when jq is missing, which is the documented
# behaviour. The skip line named `bashunit::assert_json::require_jq` instead of
# the test, so on a machine without jq every JSON test rendered under the same
# internal name and `--show-skipped` said nothing about which tests did not run
# (#1223).
#
# `bashunit::skip` reads the label two frames up -- right for a test calling it
# directly, two short for a helper reached through an assertion.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
}

# A PATH holding everything the framework needs except jq. Symlinking the real
# directories keeps the run working; dropping one name is the whole point.
function _path_without_jq() {
  local dir="$WORKDIR/nojq"
  mkdir -p "$dir"
  local p b
  for p in /bin/* /usr/bin/*; do
    b="${p##*/}"
    [ "$b" = "jq" ] && continue
    ln -sf "$p" "$dir/$b" 2>/dev/null || true
  done
  echo "$dir"
}

function _run_without_jq() { # $1 = test file
  local nojq
  nojq="$(_path_without_jq)"
  (cd "$WORKDIR" && PATH="$nojq" "$BASHUNIT_BIN" --no-parallel "$1" 2>&1 | strip_ansi) || true
}

function test_a_skipped_json_test_is_named_after_the_test() {
  if command -v jq >/dev/null 2>&1; then :; else
    bashunit::skip "needs a jq to hide" && return
  fi
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_user_has_a_name() { assert_json_key_exists ".name" "{\"name\":\"x\"}"; }'
  } >"$WORKDIR/j_test.sh"

  local output
  output="$(_run_without_jq j_test.sh)"

  assert_contains "User has a name" "$output"
  assert_not_contains "require jq" "$output"
}

# Two tests skipped for the same reason must still be told apart -- the failure
# this guards is both of them rendering as one internal name.
function test_two_skipped_json_tests_keep_their_own_names() {
  if command -v jq >/dev/null 2>&1; then :; else
    bashunit::skip "needs a jq to hide" && return
  fi
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_alpha_case() { assert_json_key_exists ".a" "{\"a\":1}"; }'
    printf '%s\n' 'function test_beta_case() { assert_json_key_not_exists ".b" "{\"a\":1}"; }'
  } >"$WORKDIR/k_test.sh"

  local output
  output="$(_run_without_jq k_test.sh)"

  assert_contains "Alpha case" "$output"
  assert_contains "Beta case" "$output"
}

# The documented contract itself: skipped, not failed, and the run still passes.
function test_a_missing_jq_skips_rather_than_fails() {
  if command -v jq >/dev/null 2>&1; then :; else
    bashunit::skip "needs a jq to hide" && return
  fi
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'function test_gamma_case() { assert_json_key_exists ".a" "{\"a\":1}"; }'
  } >"$WORKDIR/m_test.sh"

  local output
  output="$(_run_without_jq m_test.sh)"

  assert_contains "1 skipped" "$output"
  assert_not_contains "failed" "$output"
}
