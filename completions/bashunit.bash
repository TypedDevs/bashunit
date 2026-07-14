# bash completion for bashunit                            -*- shell-script -*-
#
# Install (bash-completion):
#   cp completions/bashunit.bash /usr/local/etc/bash_completion.d/bashunit
# or source it from your ~/.bashrc:
#   source /path/to/bashunit/completions/bashunit.bash
#
# Kept in sync with src/main.sh by tests/unit/completions_test.sh (anti-drift).
# Works on bash 3.2+ (plain compgen -W, no bash-completion helpers required).

_BASHUNIT_COMPLETIONS_SUBCOMMANDS="test bench doc init learn upgrade assert watch"

_BASHUNIT_COMPLETIONS_TEST_OPTS="--assert --boot --coverage --coverage-exclude \
--coverage-min --coverage-paths --coverage-report --coverage-report-html \
--debug --detailed --env --exclude-tag --fail-on-risky --failures-only \
--filter --help --jobs --log-gha --log-junit --login --no-color \
--no-coverage-report --no-output --no-output-on-failure --no-parallel \
--no-progress --output --parallel --profile --random-order --report-html \
--report-json --report-junit --report-tap --rerun-failed --retry --run-all \
--seed --shard --show-incomplete --show-output --show-skipped --simple \
--skip-env-file --stop-on-failure --strict --tag --test-timeout --verbose \
--watch -R -S -a -e -f -h -j -l -p -r -s -vvv -w"

_BASHUNIT_COMPLETIONS_ASSERT_FNS="assert_array_contains assert_array_length \
assert_array_not_contains assert_arrays_equal assert_command_not_found \
assert_contains assert_contains_ignore_case assert_date_after \
assert_date_before assert_date_equals assert_date_within_delta \
assert_date_within_range assert_directory_exists assert_directory_not_exists \
assert_duration assert_duration_greater_than assert_duration_less_than \
assert_empty assert_equals assert_exec assert_exit_code assert_false \
assert_file_contains assert_file_exists assert_file_not_contains \
assert_file_not_exists assert_file_permissions assert_files_equals \
assert_files_not_equals assert_general_error assert_greater_or_equal_than \
assert_greater_than assert_is_directory assert_is_directory_empty \
assert_is_directory_not_empty assert_is_directory_not_readable \
assert_is_directory_not_writable assert_is_directory_readable \
assert_is_directory_writable assert_is_file assert_is_file_empty \
assert_json_contains assert_json_equals assert_json_key_exists \
assert_less_or_equal_than assert_less_than assert_line_count \
assert_match_snapshot assert_match_snapshot_ignore_colors assert_matches \
assert_not_contains assert_not_empty assert_not_equals assert_not_matches \
assert_not_same assert_same assert_string_ends_with \
assert_string_matches_format assert_string_not_ends_with \
assert_string_not_matches_format assert_string_not_starts_with \
assert_string_starts_with assert_successful_code assert_true \
assert_unsuccessful_code assert_within_delta"

# compgen output is split into COMPREPLY words on purpose; mapfile/read -a would need bash 4+.
# shellcheck disable=SC2207
_bashunit_completions() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Value hints for options that take an argument.
  case "$prev" in
  --output)
    COMPREPLY=($(compgen -W "tap" -- "$cur"))
    return 0
    ;;
  -j | --jobs)
    COMPREPLY=($(compgen -W "auto" -- "$cur"))
    return 0
    ;;
  -e | --env | --boot)
    COMPREPLY=($(compgen -f -- "$cur"))
    return 0
    ;;
  -f | --filter | --tag | --exclude-tag | --retry | --seed | --shard | --test-timeout)
    return 0
    ;;
  esac

  # `bashunit assert <fn>` completes the public assertion names.
  if [ "$COMP_CWORD" -ge 2 ] && [ "${COMP_WORDS[1]}" = "assert" ]; then
    COMPREPLY=($(compgen -W "$_BASHUNIT_COMPLETIONS_ASSERT_FNS" -- "$cur"))
    return 0
  fi

  # First word: subcommands (plus flags, since `test` is the default command).
  if [ "$COMP_CWORD" -eq 1 ] && [ "${cur#-}" = "$cur" ]; then
    COMPREPLY=($(compgen -W "$_BASHUNIT_COMPLETIONS_SUBCOMMANDS" -- "$cur"))
    # Also offer test files/dirs, as `bashunit tests/` is the common shorthand.
    COMPREPLY+=($(compgen -f -- "$cur"))
    return 0
  fi

  case "$cur" in
  -*)
    COMPREPLY=($(compgen -W "$_BASHUNIT_COMPLETIONS_TEST_OPTS" -- "$cur"))
    ;;
  *)
    COMPREPLY=($(compgen -f -- "$cur"))
    ;;
  esac
  return 0
}

complete -o filenames -F _bashunit_completions bashunit 2>/dev/null || true
