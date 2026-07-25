#!/usr/bin/env bash

# _BASHUNIT_DEPRECATED_ALIASES is hand-maintained: deriving it at runtime would
# need a `compgen -v` capture, and that costs a fork on the cold-start path,
# which is budgeted (#801). These tests are what keeps a hand-maintained list
# honest -- they fail if a setting gains or loses its unprefixed alias without
# the list being updated.

# Every `: "${BASHUNIT_X:=${X:=...}}"` line in env.sh declares an unprefixed
# alias for X. That is the source of truth.
function bashunit::test::aliases_declared_in_env_sh() {
  grep -oE '^: "\$\{BASHUNIT_[A-Z0-9_]+:=\$\{[A-Z0-9_]+:=' src/env.sh |
    sed -E 's/^: "\$\{BASHUNIT_[A-Z0-9_]+:=\$\{([A-Z0-9_]+):=$/\1/' |
    sort
}

function bashunit::test::aliases_listed_in_the_constant() {
  # Unquoted on purpose: the constant is a whitespace-separated list and the
  # word splitting is what turns it into one name per line.
  # shellcheck disable=SC2086
  printf '%s\n' $_BASHUNIT_DEPRECATED_ALIASES | sort
}

function test_the_alias_list_matches_the_declarations_in_env_sh() {
  local declared listed
  declared=$(bashunit::test::aliases_declared_in_env_sh)
  listed=$(bashunit::test::aliases_listed_in_the_constant)

  assert_same "$declared" "$listed"
}

function test_the_alias_list_is_not_empty() {
  assert_not_empty "$_BASHUNIT_DEPRECATED_ALIASES"
}

# The warning must name the offending variable and point at the replacement, so
# the message is actionable without consulting the docs.
function test_warning_names_the_variable_and_its_replacement() {
  local output
  output=$(bashunit::env::warn_deprecated "the unprefixed \`VERBOSE\`" "\`BASHUNIT_VERBOSE\`" 2>&1)

  assert_contains "VERBOSE" "$output"
  assert_contains "BASHUNIT_VERBOSE" "$output"
  assert_contains "Deprecated" "$output"
}

function test_warnings_can_be_silenced() {
  local output
  output=$(BASHUNIT_NO_DEPRECATION_WARNINGS=true \
    bashunit::env::warn_deprecated "anything" "anything else" 2>&1)

  assert_empty "$output"
}

# stdout carries reports (TAP, JSON); a warning there would corrupt them.
function test_warning_goes_to_stderr_not_stdout() {
  local on_stdout
  on_stdout=$(bashunit::env::warn_deprecated "the unprefixed \`VERBOSE\`" "\`BASHUNIT_VERBOSE\`" 2>/dev/null)

  assert_empty "$on_stdout"
}
