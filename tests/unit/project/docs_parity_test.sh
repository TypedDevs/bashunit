#!/usr/bin/env bash
set -euo pipefail

# The docs drifted behind the code for several releases before a full audit found
# it: 17 registered settings were missing from docs/configuration.md, 19 from
# .env.example, and two flags existed in the parser but not in --help. Reviews do
# not catch that reliably, so it is a test.
#
# The checks compare *sets of names*, never prose, so a rewording never breaks
# them. Adding a flag or a setting without documenting it does.

function set_up_before_script() {
  ENV_FILE="src/config/env.sh"
  ENV_EXAMPLE=".env.example"
  CONFIG_DOC="docs/configuration.md"
  CLI_DOC="docs/command-line.md"
}

# Every `: "${BASHUNIT_X:=...}"` line in env.sh, one name per line, sorted.
# BASHUNIT_NO_DEPRECATION_WARNINGS is a read-only opt-out consulted with `:-`
# rather than registered with a default, so it is added explicitly.
function _registered_settings() {
  {
    grep -oE '^[[:space:]]*: "\$\{BASHUNIT_[A-Z_]+' "$ENV_FILE" | sed 's/.*{//'
    echo "BASHUNIT_NO_DEPRECATION_WARNINGS"
  } | sort -u
}

function _documented_in_env_example() {
  grep -oE '^#?BASHUNIT_[A-Z_]+' "$ENV_EXAMPLE" | sed 's/^#//' | sort -u
}

function _documented_in_configuration() {
  grep -oE 'BASHUNIT_[A-Z_]+' "$CONFIG_DOC" | sort -u
}

function test_every_registered_setting_appears_in_env_example() {
  local missing
  missing="$(comm -23 <(_registered_settings) <(_documented_in_env_example) | tr '\n' ' ')"

  assert_empty "$missing"
}

function test_env_example_lists_no_setting_that_does_not_exist() {
  local unknown
  unknown="$(comm -13 <(_registered_settings) <(_documented_in_env_example) | tr '\n' ' ')"

  assert_empty "$unknown"
}

function test_every_registered_setting_is_documented_in_configuration_md() {
  local missing
  missing="$(comm -23 <(_registered_settings) <(_documented_in_configuration) | tr '\n' ' ')"

  assert_empty "$missing"
}

# The reverse direction: a page naming a setting the code no longer registers is
# just as misleading as an undocumented one.
function test_configuration_md_documents_no_setting_that_does_not_exist() {
  local unknown
  unknown="$(comm -13 <(_registered_settings) <(_documented_in_configuration) | tr '\n' ' ')"

  assert_empty "$unknown"
}

# Long flags advertised by `bashunit test --help`.
function _help_flags() {
  ./bashunit test --help 2>&1 | grep -oE '(^|[ ,])--[a-z][a-z-]+' |
    tr -d ' ,' | sort -u
}

# Long flags the reference page mentions anywhere. Two deliberate typos live in
# the "Unknown options" example, and `--custom` belongs to the doc subcommand.
function _cli_doc_flags() {
  grep -ohE '\-\-[a-z][a-z-]+' "$CLI_DOC" | sort -u |
    grep -vxE -- '--(parralel|filterr|custom|version)'
}

function test_every_flag_in_the_help_is_documented_on_the_command_line_page() {
  local missing
  missing="$(comm -23 <(_help_flags) <(_cli_doc_flags) | tr '\n' ' ')"

  assert_empty "$missing"
}

# A documented flag that no parser branch accepts would exit non-zero with
# "unknown option" the moment a reader copied it.
function test_every_flag_on_the_command_line_page_is_accepted_by_a_parser() {
  local flag unknown=""
  while IFS= read -r flag; do
    [ -z "$flag" ] && continue
    # A branch may list alternatives: `-e | --env | --boot)`, so the flag can be
    # followed by `)` or by ` |` instead.
    if ! grep -qE -- "[[:space:]|(]$flag([[:space:]]*\||\))" \
      src/main/test.sh src/main/bench.sh src/main/subcommands.sh \
      src/cli/watch.sh bashunit; then
      unknown="$unknown $flag"
    fi
  done < <(_cli_doc_flags)

  assert_empty "$unknown"
}
