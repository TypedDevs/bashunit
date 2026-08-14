#!/usr/bin/env bash
set -euo pipefail

# The configuration precedence ladder is six levels deep and every level is a
# claim in docs/configuration.md that nothing executed. The two files are read
# by different code -- `.env` is sourced with a preservation pass for values the
# file blanks, the `--env`/`--boot` file is a plain `source` under allexport --
# so the levels can drift apart without either side erroring.
#
# The blanking rule is the one that was documented wrong: an empty entry in the
# `--env` file assigns the empty string, which for a boolean is not the default
# but `false` (#1217).
#
# BASHUNIT_SHOW_HEADER (default true) is the probe for the file/environment
# levels; BASHUNIT_SIMPLE_OUTPUT for the two that need a real CLI flag.

function set_up_before_script() {
  BASHUNIT_BIN="$(pwd)/bashunit"
}

function set_up() {
  WORKDIR="$(bashunit::temp_dir)"
  printf '%s\n' '#!/usr/bin/env bash' 'function test_ok() { assert_same 1 1; }' \
    >"$WORKDIR/t_test.sh"
}

# Says "shown" or "hidden" for the run header. Every call is a fresh process, so
# the ambient value is passed in rather than exported here.
#
# The "unset" case has to unset it *in the subshell* rather than just not
# setting it: CI runs `cp .env.example .env`, and `.env` is sourced under
# allexport, so the outer run exports BASHUNIT_SHOW_HEADER to every child. An
# inherited value outranks `.bashunitrc` -- correctly, per the ladder -- which
# made the `.bashunitrc` case fail on Linux and the two `--skip-env-file` and
# `--env` cases pass for the wrong reason.
function _header() { # $1 = ambient BASHUNIT_SHOW_HEADER ("" for unset), $@ = extra args
  local ambient="$1"
  shift
  local output
  if [ -n "$ambient" ]; then
    output=$(cd "$WORKDIR" && BASHUNIT_SHOW_HEADER="$ambient" \
      "$BASHUNIT_BIN" --no-parallel "$@" t_test.sh 2>&1 | strip_ansi) || true
  else
    output=$(cd "$WORKDIR" && unset BASHUNIT_SHOW_HEADER &&
      "$BASHUNIT_BIN" --no-parallel "$@" t_test.sh 2>&1 | strip_ansi) || true
  fi
  # The header is colour-wrapped, so this must run on stripped output: an
  # unstripped match silently never fires and every case reads as "hidden".
  case "$output" in
  *"bashunit - "*) echo "shown" ;;
  *) echo "hidden" ;;
  esac
}

function _simple() { # $@ = args; says "simple" or "verbose"
  local output
  output=$(cd "$WORKDIR" && unset BASHUNIT_SIMPLE_OUTPUT &&
    "$BASHUNIT_BIN" --no-parallel "$@" t_test.sh 2>&1) || true
  case "$output" in
  *"Passed"*) echo "verbose" ;;
  *) echo "simple" ;;
  esac
}

function test_the_builtin_default_shows_the_header() {
  assert_same "shown" "$(_header "")"
}

function test_bashunitrc_beats_the_builtin_default() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/.bashunitrc"

  assert_same "hidden" "$(_header "")"
}

function test_the_environment_beats_bashunitrc() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/.bashunitrc"

  assert_same "shown" "$(_header "true")"
}

function test_an_env_entry_with_a_value_beats_the_environment() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/.env"

  assert_same "hidden" "$(_header "true")"
}

# "Not configured here": .env snapshots and restores values it blanks.
function test_an_empty_env_entry_preserves_the_environment() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=' >"$WORKDIR/.env"

  assert_same "shown" "$(_header "true")"
}

function test_the_env_flag_file_beats_dot_env() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=true' >"$WORKDIR/.env"
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/custom.env"

  assert_same "hidden" "$(_header "" --env custom.env)"
}

function test_the_env_flag_file_beats_the_environment() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/custom.env"

  assert_same "hidden" "$(_header "true" --env custom.env)"
}

# The documented difference from .env, stated in terms of what is observable:
# the entry overrides, and an empty value is not the default. With the default
# being `true`, a wipe-to-default would show the header; an empty string does
# not equal "true", so it hides it.
function test_an_empty_entry_in_the_env_flag_file_is_not_the_default() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=' >"$WORKDIR/custom.env"

  assert_same "hidden" "$(_header "true" --env custom.env)"
}

function test_skip_env_file_skips_both_files() {
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/.env"
  printf '%s\n' 'BASHUNIT_SHOW_HEADER=false' >"$WORKDIR/.bashunitrc"

  assert_same "shown" "$(_header "" --skip-env-file)"
}

# The --env file is sourced during flag parsing, so it beats a flag written
# before it and loses to one written after.
function test_a_flag_before_the_env_flag_file_loses_to_it() {
  printf '%s\n' 'BASHUNIT_SIMPLE_OUTPUT=false' >"$WORKDIR/custom.env"

  assert_same "verbose" "$(_simple --simple --env custom.env)"
}

function test_a_flag_after_the_env_flag_file_wins() {
  printf '%s\n' 'BASHUNIT_SIMPLE_OUTPUT=false' >"$WORKDIR/custom.env"

  assert_same "simple" "$(_simple --env custom.env --simple)"
}
