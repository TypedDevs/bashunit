#!/usr/bin/env bash
# shellcheck disable=SC2317

# Anti-drift contract: the static completion scripts under completions/ must
# stay in sync with the flags parsed by the test subcommand in src/main.sh,
# the subcommand list in the bashunit entrypoint, and the public assertions.

BASH_COMPLETION_FILE="completions/bashunit.bash"
ZSH_COMPLETION_FILE="completions/_bashunit"

# Flags accepted by cmd_test, straight from the option-parsing case arms.
function completions_expected_test_flags() {
  awk '/# Parse test-specific options/,/^  done$/' src/main.sh |
    grep -E '^[[:space:]]+--?[a-zA-Z][a-zA-Z0-9-]*( \| --?[a-zA-Z][a-zA-Z0-9-]*)*\)' |
    sed 's/)$//' | tr -d ' ' | tr '|' '\n' |
    LC_ALL=C sort -u
}

function completions_expected_assert_functions() {
  grep -hoE '^function assert_[a-z_0-9]+' src/assert*.sh |
    sed 's/^function //' | LC_ALL=C sort -u
}

# Flags advertised by the bash completion script (single source variable).
function completions_bash_flags() {
  (
    # shellcheck source=/dev/null
    source "$BASH_COMPLETION_FILE" 2>/dev/null
    echo "$_BASHUNIT_COMPLETIONS_TEST_OPTS" | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort -u
  )
}

# Flags advertised by the zsh completion script: strip [descriptions], then
# collect every -x/--long token.
function completions_zsh_flags() {
  # Each punctuation char maps to a space (char-by-char); the repeated spaces are intentional.
  # shellcheck disable=SC2020
  sed 's/\[[^]]*\]//g' "$ZSH_COMPLETION_FILE" |
    tr '{}(),"'"'"':' '      ' | tr ' \t' '\n\n' |
    grep -E '^--?[a-zA-Z][a-zA-Z0-9-]*$' |
    LC_ALL=C sort -u
}

function test_bash_completion_script_exists_and_passes_syntax_check() {
  assert_file_exists "$BASH_COMPLETION_FILE"
  assert_successful_code "$(bash -n "$BASH_COMPLETION_FILE" 2>&1)"
}

function test_zsh_completion_script_exists_and_passes_syntax_check() {
  assert_file_exists "$ZSH_COMPLETION_FILE"
  if ! command -v zsh >/dev/null 2>&1; then
    bashunit::skip "zsh not available" && return
  fi
  assert_successful_code "$(zsh -n "$ZSH_COMPLETION_FILE" 2>&1)"
}

function test_bash_completion_flags_match_main_sh() {
  local expected actual
  expected=$(completions_expected_test_flags)
  actual=$(completions_bash_flags)

  assert_same "$expected" "$actual"
}

function test_zsh_completion_flags_match_main_sh() {
  local expected actual
  expected=$(completions_expected_test_flags)
  actual=$(completions_zsh_flags)

  assert_same "$expected" "$actual"
}

function test_bash_completion_lists_all_subcommands() {
  local subcommands
  subcommands=$(
    # shellcheck source=/dev/null
    source "$BASH_COMPLETION_FILE" 2>/dev/null
    echo "$_BASHUNIT_COMPLETIONS_SUBCOMMANDS"
  )

  local sub
  for sub in test bench doc init learn upgrade assert watch; do
    assert_contains "$sub" "$subcommands"
  done
}

function test_zsh_completion_lists_all_subcommands() {
  local content
  content=$(cat "$ZSH_COMPLETION_FILE")

  local sub
  for sub in test bench doc init learn upgrade assert watch; do
    assert_contains "$sub" "$content"
  done
}

function test_bash_completion_assert_functions_match_src() {
  local expected actual
  expected=$(completions_expected_assert_functions)
  actual=$(
    # shellcheck source=/dev/null
    source "$BASH_COMPLETION_FILE" 2>/dev/null
    echo "$_BASHUNIT_COMPLETIONS_ASSERT_FNS" | tr ' ' '\n' | grep -v '^$' | LC_ALL=C sort -u
  )

  assert_same "$expected" "$actual"
}
