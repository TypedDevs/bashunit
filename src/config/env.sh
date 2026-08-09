#!/usr/bin/env bash

# shellcheck disable=SC2034

##
# Loads a project config file of `KEY=value` lines (comments with `#` and blank
# lines are ignored). Each key is only applied when not already set in the
# environment, so real env vars and CLI flags keep precedence over the file.
# Surrounding single/double quotes and an optional `export ` prefix are stripped.
# Arguments: $1 path to the config file
##
function bashunit::env::load_config_file() {
  local file=$1
  [ -f "$file" ] || return 0

  local line key val
  while IFS= read -r line || [ -n "$line" ]; do
    # Trim leading whitespace
    line=${line#"${line%%[![:space:]]*}"}
    case "$line" in
    '' | '#'*) continue ;;
    esac
    case "$line" in export\ *) line=${line#export } ;; esac
    case "$line" in
    *=*) ;;
    *) continue ;;
    esac

    key=${line%%=*}
    val=${line#*=}

    # Only accept valid shell identifiers (defends the eval below)
    case "$key" in
    '' | *[!A-Za-z0-9_]* | [0-9]*) continue ;;
    esac

    # Strip surrounding matching quotes
    case "$val" in
    \"*\") val=${val#\"} val=${val%\"} ;;
    \'*\') val=${val#\'} val=${val%\'} ;;
    esac

    # Apply only when unset: env var / CLI flag > config file
    eval "export $key=\"\${$key:-\$val}\""
  done <"$file"
}

##
# Reports a deprecated form once per run, on stderr so it cannot corrupt a
# report on stdout. Silence with BASHUNIT_NO_DEPRECATION_WARNINGS=true.
#
# The deprecation policy: a form that still works but is on its way out warns
# here for at least one minor release before it is removed in a major one. That
# gives the warning somewhere to live instead of the deprecation sitting
# indefinitely in a help string nobody reads.
#
# Arguments: $1 the deprecated form, $2 what to use instead
##
function bashunit::env::warn_deprecated() {
  [ "${BASHUNIT_NO_DEPRECATION_WARNINGS:-false}" = "true" ] && return 0

  printf "%sDeprecated: %s. Use %s instead.%s\n" \
    "${_BASHUNIT_COLOR_SKIPPED:-}" "$1" "$2" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
}

##
# Echoes $1 when it is a positive integer, otherwise echoes the default $2.
# Arguments: $1 candidate value, $2 fallback default
##
function bashunit::env::positive_int_or_default() {
  local value="$1"
  local default="$2"
  case "$value" in
  '' | *[!0-9]* | 0) echo "$default" ;;
  *) echo "$value" ;;
  esac
}

# Load project config (lower precedence than env vars, .env and CLI flags).
# Load .env file (skip if --skip-env-file is used to keep shell environment intact)
if [ "${BASHUNIT_SKIP_ENV_FILE:-false}" != "true" ]; then
  bashunit::env::load_config_file ".bashunitrc"

  if [ -f ".env" ]; then
    # `.env` is sourced under allexport so it can hold arbitrary shell, which
    # means every `KEY=` line is an unconditional assignment: an empty entry used
    # to wipe a value the caller exported, so a project could not document a
    # setting without breaking it on the command line (#865).
    #
    # Snapshot the caller's non-empty BASHUNIT_* values and put back any the file
    # blanked. A non-empty entry still wins -- that is what a project config is
    # for -- and only an empty one is treated as "not configured here", matching
    # how .bashunitrc already applies values.
    _bashunit_env_preserved=""
    for _bashunit_env_name in $(compgen -v BASHUNIT_ 2>/dev/null || true); do
      eval "_bashunit_env_value=\${$_bashunit_env_name}"
      if [ -n "$_bashunit_env_value" ]; then
        _bashunit_env_preserved="$_bashunit_env_preserved $_bashunit_env_name"
        eval "_bashunit_env_saved_$_bashunit_env_name=\$_bashunit_env_value"
      fi
    done

    set -o allexport
    # shellcheck source=/dev/null
    source .env
    set +o allexport

    for _bashunit_env_name in $_bashunit_env_preserved; do
      eval "_bashunit_env_value=\${$_bashunit_env_name}"
      if [ -z "$_bashunit_env_value" ]; then
        eval "export $_bashunit_env_name=\$_bashunit_env_saved_$_bashunit_env_name"
      fi
      eval "unset _bashunit_env_saved_$_bashunit_env_name"
    done

    unset _bashunit_env_preserved _bashunit_env_name _bashunit_env_value
  fi
fi

# Settings that still answer to an unprefixed name (`VERBOSE`, `COVERAGE`, …).
# The prefix landed in 0.15.0; these remain only for back-compat and are an
# active hazard, because the names are generic enough that an unrelated tool
# exporting COVERAGE=true silently reconfigures bashunit (#866).
#
# Kept in sync with the `: "${BASHUNIT_X:=${X:=…}}"` lines below by
# tests/unit/env_deprecated_aliases_test.sh, which fails if the two drift.
_BASHUNIT_DEPRECATED_ALIASES="DEFAULT_PATH DEV_LOG BOOTSTRAP BOOTSTRAP_ARGS
LOG_JUNIT LOG_GHA REPORT_HTML REPORT_TAP REPORT_JSON WATCH_INTERVAL COVERAGE
COVERAGE_PATHS COVERAGE_EXCLUDE COVERAGE_REPORT COVERAGE_REPORT_HTML
COVERAGE_MIN COVERAGE_THRESHOLD_LOW COVERAGE_THRESHOLD_HIGH PARALLEL_RUN
SHOW_HEADER HEADER_ASCII_ART SIMPLE_OUTPUT STOP_ON_FAILURE SHOW_EXECUTION_TIME
VERBOSE BENCH_MODE NO_OUTPUT INTERNAL_LOG SHOW_SKIPPED SHOW_INCOMPLETE
STRICT_MODE STOP_ON_ASSERTION_FAILURE SKIP_ENV_FILE LOGIN_SHELL FAILURES_ONLY
SHOW_OUTPUT_ON_FAILURE NO_DIFF NO_PROGRESS OUTPUT_FORMAT FAIL_ON_RISKY PROFILE
PROFILE_COUNT TEST_TIMEOUT"

# Record which unprefixed names are about to supply a value. Runs BEFORE the
# `:=` block below, because after it the prefixed name is set either way and the
# two cases are indistinguishable. Pure bash: a `compgen -v` capture would cost
# a fork on the cold-start path, which is budgeted (#801).
_bashunit_deprecated_in_use=""
for _bashunit_alias in $_BASHUNIT_DEPRECATED_ALIASES; do
  eval "_bashunit_alias_prefixed=\${BASHUNIT_$_bashunit_alias+set}"
  [ -n "$_bashunit_alias_prefixed" ] && continue
  eval "_bashunit_alias_value=\${$_bashunit_alias:-}"
  [ -n "$_bashunit_alias_value" ] &&
    _bashunit_deprecated_in_use="$_bashunit_deprecated_in_use $_bashunit_alias"
done
unset _bashunit_alias _bashunit_alias_prefixed _bashunit_alias_value

if [ -n "$_bashunit_deprecated_in_use" ]; then
  for _bashunit_alias in $_bashunit_deprecated_in_use; do
    bashunit::env::warn_deprecated \
      "the unprefixed \`$_bashunit_alias\`" "\`BASHUNIT_$_bashunit_alias\`"
  done
  unset _bashunit_alias
fi

_BASHUNIT_DEFAULT_DEFAULT_PATH="tests"
_BASHUNIT_DEFAULT_BOOTSTRAP="tests/bootstrap.sh"
_BASHUNIT_DEFAULT_DEV_LOG=""
_BASHUNIT_DEFAULT_LOG_JUNIT=""
_BASHUNIT_DEFAULT_LOG_GHA=""
_BASHUNIT_DEFAULT_REPORT_HTML=""
_BASHUNIT_DEFAULT_REPORT_TAP=""
_BASHUNIT_DEFAULT_REPORT_JSON=""

# Coverage defaults (following kcov, bashcov, SimpleCov conventions)
_BASHUNIT_DEFAULT_COVERAGE="false"
_BASHUNIT_DEFAULT_COVERAGE_PATHS=""
_BASHUNIT_DEFAULT_COVERAGE_EXCLUDE="tests/*,vendor/*,*_test.sh,*Test.sh"
_BASHUNIT_DEFAULT_COVERAGE_REPORT="coverage/lcov.info"
_BASHUNIT_DEFAULT_COVERAGE_REPORT_HTML=""
_BASHUNIT_DEFAULT_COVERAGE_MIN=""
_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW="50"
_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH="80"
# Per-line execution counts in the text coverage report (#856)
_BASHUNIT_DEFAULT_COVERAGE_SHOW_LINE_HITS="false"
# Tracing engine: auto|xtrace|trap. auto takes the xtrace fast path wherever
# BASH_XTRACEFD exists (Bash 4.1+) and the DEBUG trap below it (ADR-009, #860)
_BASHUNIT_DEFAULT_COVERAGE_ENGINE="auto"

: "${BASHUNIT_DEFAULT_PATH:=${DEFAULT_PATH:=$_BASHUNIT_DEFAULT_DEFAULT_PATH}}"
: "${BASHUNIT_DEV_LOG:=${DEV_LOG:=$_BASHUNIT_DEFAULT_DEV_LOG}}"
: "${BASHUNIT_BOOTSTRAP:=${BOOTSTRAP:=$_BASHUNIT_DEFAULT_BOOTSTRAP}}"
: "${BASHUNIT_BOOTSTRAP_ARGS:=${BOOTSTRAP_ARGS:=}}"
: "${BASHUNIT_LOG_JUNIT:=${LOG_JUNIT:=$_BASHUNIT_DEFAULT_LOG_JUNIT}}"
: "${BASHUNIT_LOG_GHA:=${LOG_GHA:=$_BASHUNIT_DEFAULT_LOG_GHA}}"
: "${BASHUNIT_REPORT_HTML:=${REPORT_HTML:=$_BASHUNIT_DEFAULT_REPORT_HTML}}"
: "${BASHUNIT_REPORT_TAP:=${REPORT_TAP:=$_BASHUNIT_DEFAULT_REPORT_TAP}}"
: "${BASHUNIT_REPORT_JSON:=${REPORT_JSON:=$_BASHUNIT_DEFAULT_REPORT_JSON}}"

# Watch mode polling interval (seconds) used by the pure-shell fallback
_BASHUNIT_DEFAULT_WATCH_INTERVAL="2"
: "${BASHUNIT_WATCH_INTERVAL:=${WATCH_INTERVAL:=$_BASHUNIT_DEFAULT_WATCH_INTERVAL}}"
BASHUNIT_WATCH_INTERVAL=$(bashunit::env::positive_int_or_default \
  "$BASHUNIT_WATCH_INTERVAL" "$_BASHUNIT_DEFAULT_WATCH_INTERVAL")

# Coverage
: "${BASHUNIT_COVERAGE:=${COVERAGE:=$_BASHUNIT_DEFAULT_COVERAGE}}"
: "${BASHUNIT_COVERAGE_PATHS:=${COVERAGE_PATHS:=$_BASHUNIT_DEFAULT_COVERAGE_PATHS}}"
: "${BASHUNIT_COVERAGE_EXCLUDE:=${COVERAGE_EXCLUDE:=$_BASHUNIT_DEFAULT_COVERAGE_EXCLUDE}}"
: "${BASHUNIT_COVERAGE_REPORT:=${COVERAGE_REPORT:=$_BASHUNIT_DEFAULT_COVERAGE_REPORT}}"
: "${BASHUNIT_COVERAGE_REPORT_HTML:=${COVERAGE_REPORT_HTML:=$_BASHUNIT_DEFAULT_COVERAGE_REPORT_HTML}}"
: "${BASHUNIT_COVERAGE_MIN:=${COVERAGE_MIN:=$_BASHUNIT_DEFAULT_COVERAGE_MIN}}"
: "${BASHUNIT_COVERAGE_THRESHOLD_LOW:=${COVERAGE_THRESHOLD_LOW:=$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW}}"
: "${BASHUNIT_COVERAGE_THRESHOLD_HIGH:=${COVERAGE_THRESHOLD_HIGH:=$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH}}"
# No bare COVERAGE_SHOW_LINE_HITS alias: registering the default here is a
# no-op consolidation, whereas adding the alias would widen the public API.
# bashunit::coverage keeps its :- guard for callers that unset it.
: "${BASHUNIT_COVERAGE_SHOW_LINE_HITS:=$_BASHUNIT_DEFAULT_COVERAGE_SHOW_LINE_HITS}"
# No bare COVERAGE_ENGINE alias: the unprefixed forms are deprecated, so a new
# setting only ever ships under the BASHUNIT_ prefix.
: "${BASHUNIT_COVERAGE_ENGINE:=$_BASHUNIT_DEFAULT_COVERAGE_ENGINE}"

# Booleans
_BASHUNIT_DEFAULT_PARALLEL_RUN="false"
# Worker cap for --parallel (0 = unbounded)
_BASHUNIT_DEFAULT_PARALLEL_JOBS="0"
_BASHUNIT_DEFAULT_SHOW_HEADER="true"
_BASHUNIT_DEFAULT_HEADER_ASCII_ART="false"
_BASHUNIT_DEFAULT_SIMPLE_OUTPUT="false"
_BASHUNIT_DEFAULT_STOP_ON_FAILURE="false"
# "auto" shows per-test times only when the clock is fork-free (#765).
_BASHUNIT_DEFAULT_SHOW_EXECUTION_TIME="auto"
_BASHUNIT_DEFAULT_VERBOSE="false"
_BASHUNIT_DEFAULT_BENCH_MODE="false"
_BASHUNIT_DEFAULT_NO_OUTPUT="false"
_BASHUNIT_DEFAULT_INTERNAL_LOG="false"
_BASHUNIT_DEFAULT_SHOW_SKIPPED="false"
_BASHUNIT_DEFAULT_SHOW_INCOMPLETE="false"
_BASHUNIT_DEFAULT_STRICT_MODE="false"
_BASHUNIT_DEFAULT_STOP_ON_ASSERTION_FAILURE="true"
_BASHUNIT_DEFAULT_SKIP_ENV_FILE="false"
_BASHUNIT_DEFAULT_LOGIN_SHELL="false"
_BASHUNIT_DEFAULT_FAILURES_ONLY="false"
_BASHUNIT_DEFAULT_NO_COLOR="false"
_BASHUNIT_DEFAULT_NO_DIFF="false"
_BASHUNIT_DEFAULT_SHOW_OUTPUT_ON_FAILURE="true"
_BASHUNIT_DEFAULT_NO_PROGRESS="false"
_BASHUNIT_DEFAULT_OUTPUT_FORMAT=""
_BASHUNIT_DEFAULT_FAIL_ON_RISKY="false"
_BASHUNIT_DEFAULT_PROFILE="false"
_BASHUNIT_DEFAULT_PROFILE_COUNT="10"
# Per-test timeout in seconds (0 = disabled)
_BASHUNIT_DEFAULT_TEST_TIMEOUT="0"
# Extra attempts for a failed test (0 = no retry)
_BASHUNIT_DEFAULT_RETRY="0"
# Randomize test execution order to surface inter-test coupling
_BASHUNIT_DEFAULT_RANDOM_ORDER="false"
# Seed for --random-order (empty = generate one and print it)
_BASHUNIT_DEFAULT_SEED=""
# Shard <index>/<total> to split the suite across runners (empty = disabled)
_BASHUNIT_DEFAULT_SHARD_INDEX=""
_BASHUNIT_DEFAULT_SHARD_TOTAL=""
# Replay only the tests recorded as failing by the previous run
_BASHUNIT_DEFAULT_RERUN_FAILED="false"
# Rewrite existing snapshots from the actual value instead of comparing
_BASHUNIT_DEFAULT_SNAPSHOT_UPDATE="false"
# Record a snapshot the first time it is asserted (false = a missing one fails)
_BASHUNIT_DEFAULT_SNAPSHOT_CREATE="true"
# Report snapshot files that no test resolved during the run
_BASHUNIT_DEFAULT_SNAPSHOT_REPORT_UNUSED="false"

: "${BASHUNIT_PARALLEL_RUN:=${PARALLEL_RUN:=$_BASHUNIT_DEFAULT_PARALLEL_RUN}}"
: "${BASHUNIT_PARALLEL_JOBS:=$_BASHUNIT_DEFAULT_PARALLEL_JOBS}"
: "${BASHUNIT_SHOW_HEADER:=${SHOW_HEADER:=$_BASHUNIT_DEFAULT_SHOW_HEADER}}"
: "${BASHUNIT_HEADER_ASCII_ART:=${HEADER_ASCII_ART:=$_BASHUNIT_DEFAULT_HEADER_ASCII_ART}}"
: "${BASHUNIT_SIMPLE_OUTPUT:=${SIMPLE_OUTPUT:=$_BASHUNIT_DEFAULT_SIMPLE_OUTPUT}}"
: "${BASHUNIT_STOP_ON_FAILURE:=${STOP_ON_FAILURE:=$_BASHUNIT_DEFAULT_STOP_ON_FAILURE}}"
: "${BASHUNIT_SHOW_EXECUTION_TIME:=${SHOW_EXECUTION_TIME:=$_BASHUNIT_DEFAULT_SHOW_EXECUTION_TIME}}"
: "${BASHUNIT_VERBOSE:=${VERBOSE:=$_BASHUNIT_DEFAULT_VERBOSE}}"
: "${BASHUNIT_BENCH_MODE:=${BENCH_MODE:=$_BASHUNIT_DEFAULT_BENCH_MODE}}"
: "${BASHUNIT_NO_OUTPUT:=${NO_OUTPUT:=$_BASHUNIT_DEFAULT_NO_OUTPUT}}"
: "${BASHUNIT_INTERNAL_LOG:=${INTERNAL_LOG:=$_BASHUNIT_DEFAULT_INTERNAL_LOG}}"
: "${BASHUNIT_SHOW_SKIPPED:=${SHOW_SKIPPED:=$_BASHUNIT_DEFAULT_SHOW_SKIPPED}}"
: "${BASHUNIT_SHOW_INCOMPLETE:=${SHOW_INCOMPLETE:=$_BASHUNIT_DEFAULT_SHOW_INCOMPLETE}}"
: "${BASHUNIT_STRICT_MODE:=${STRICT_MODE:=$_BASHUNIT_DEFAULT_STRICT_MODE}}"
: "${BASHUNIT_STOP_ON_ASSERTION_FAILURE:=${STOP_ON_ASSERTION_FAILURE:=$_BASHUNIT_DEFAULT_STOP_ON_ASSERTION_FAILURE}}"
: "${BASHUNIT_SKIP_ENV_FILE:=${SKIP_ENV_FILE:=$_BASHUNIT_DEFAULT_SKIP_ENV_FILE}}"
: "${BASHUNIT_LOGIN_SHELL:=${LOGIN_SHELL:=$_BASHUNIT_DEFAULT_LOGIN_SHELL}}"
: "${BASHUNIT_FAILURES_ONLY:=${FAILURES_ONLY:=$_BASHUNIT_DEFAULT_FAILURES_ONLY}}"
: "${BASHUNIT_SHOW_OUTPUT_ON_FAILURE:=${SHOW_OUTPUT_ON_FAILURE:=$_BASHUNIT_DEFAULT_SHOW_OUTPUT_ON_FAILURE}}"
: "${BASHUNIT_NO_DIFF:=${NO_DIFF:=$_BASHUNIT_DEFAULT_NO_DIFF}}"
: "${BASHUNIT_NO_PROGRESS:=${NO_PROGRESS:=$_BASHUNIT_DEFAULT_NO_PROGRESS}}"
: "${BASHUNIT_OUTPUT_FORMAT:=${OUTPUT_FORMAT:=$_BASHUNIT_DEFAULT_OUTPUT_FORMAT}}"
: "${BASHUNIT_FAIL_ON_RISKY:=${FAIL_ON_RISKY:=$_BASHUNIT_DEFAULT_FAIL_ON_RISKY}}"
: "${BASHUNIT_PROFILE:=${PROFILE:=$_BASHUNIT_DEFAULT_PROFILE}}"
: "${BASHUNIT_PROFILE_COUNT:=${PROFILE_COUNT:=$_BASHUNIT_DEFAULT_PROFILE_COUNT}}"
: "${BASHUNIT_TEST_TIMEOUT:=${TEST_TIMEOUT:=$_BASHUNIT_DEFAULT_TEST_TIMEOUT}}"
# No bare RETRY alias on purpose: it is too generic and would pick up unrelated
# environment values. Only BASHUNIT_RETRY configures retries.
: "${BASHUNIT_RETRY:=$_BASHUNIT_DEFAULT_RETRY}"
# Single alias on purpose: bare RANDOM_ORDER/SEED are too generic and would pick
# up unrelated environment values.
: "${BASHUNIT_RANDOM_ORDER:=$_BASHUNIT_DEFAULT_RANDOM_ORDER}"
: "${BASHUNIT_SEED:=$_BASHUNIT_DEFAULT_SEED}"
: "${BASHUNIT_SHARD_INDEX:=$_BASHUNIT_DEFAULT_SHARD_INDEX}"
: "${BASHUNIT_SHARD_TOTAL:=$_BASHUNIT_DEFAULT_SHARD_TOTAL}"
# No bare RERUN_FAILED alias, same reasoning as RETRY/SEED above. The default
# lives here rather than inline in rerun.sh so every BASHUNIT_* default has one
# home; bashunit::rerun::is_enabled keeps its :- guard for callers that unset it.
: "${BASHUNIT_RERUN_FAILED:=$_BASHUNIT_DEFAULT_RERUN_FAILED}"
# No bare SNAPSHOT_UPDATE alias either: rewriting files on disk is the last
# setting that should be reachable by a generic name from the environment.
: "${BASHUNIT_SNAPSHOT_UPDATE:=$_BASHUNIT_DEFAULT_SNAPSHOT_UPDATE}"
: "${BASHUNIT_SNAPSHOT_CREATE:=$_BASHUNIT_DEFAULT_SNAPSHOT_CREATE}"
: "${BASHUNIT_SNAPSHOT_REPORT_UNUSED:=$_BASHUNIT_DEFAULT_SNAPSHOT_REPORT_UNUSED}"
# Support NO_COLOR standard (https://no-color.org)
if [ -n "${NO_COLOR:-}" ]; then
  BASHUNIT_NO_COLOR="true"
else
  : "${BASHUNIT_NO_COLOR:=$_BASHUNIT_DEFAULT_NO_COLOR}"
fi

function bashunit::env::is_parallel_run_enabled() {
  [ "$BASHUNIT_PARALLEL_RUN" = "true" ]
}

##
# Whether a per-test timeout is configured (a positive integer number of seconds).
# Returns: 0 when enabled, 1 otherwise.
##
function bashunit::env::is_test_timeout_enabled() {
  case "${BASHUNIT_TEST_TIMEOUT:-0}" in
  '' | *[!0-9]*) return 1 ;;
  esac
  [ "${BASHUNIT_TEST_TIMEOUT:-0}" -gt 0 ]
}

##
# Prints the configured per-test timeout in seconds (0 when disabled).
##
function bashunit::env::test_timeout_secs() {
  printf '%s' "${BASHUNIT_TEST_TIMEOUT:-0}"
}

##
# Prints the number of extra attempts for a failed test (0 = no retry).
# A non-numeric value is treated as 0.
##
# Validates BASHUNIT_RETRY into the integer global _BASHUNIT_RETRY_VALIDATED.
# In-shell (no fork) so the per-test hot path can read the global instead of
# capturing retry_count in a $(...) subshell every test (#764).
_BASHUNIT_RETRY_VALIDATED=0
function bashunit::env::resolve_retry_count() {
  case "${BASHUNIT_RETRY:-0}" in
  '' | *[!0-9]*) _BASHUNIT_RETRY_VALIDATED=0 ;;
  *) _BASHUNIT_RETRY_VALIDATED="${BASHUNIT_RETRY:-0}" ;;
  esac
}

function bashunit::env::retry_count() {
  bashunit::env::resolve_retry_count
  printf '%s' "$_BASHUNIT_RETRY_VALIDATED"
}

function bashunit::env::is_random_order_enabled() {
  [ "$BASHUNIT_RANDOM_ORDER" = "true" ]
}

##
# Prints the configured random-order seed (empty when none set yet).
##
function bashunit::env::seed() {
  printf '%s' "${BASHUNIT_SEED:-}"
}

function bashunit::env::is_shard_enabled() {
  [ -n "${BASHUNIT_SHARD_INDEX:-}" ] && [ -n "${BASHUNIT_SHARD_TOTAL:-}" ]
}

function bashunit::env::shard_index() {
  printf '%s' "${BASHUNIT_SHARD_INDEX:-}"
}

function bashunit::env::shard_total() {
  printf '%s' "${BASHUNIT_SHARD_TOTAL:-}"
}

function bashunit::env::is_show_header_enabled() {
  [ "$BASHUNIT_SHOW_HEADER" = "true" ]
}

function bashunit::env::is_header_ascii_art_enabled() {
  [ "$BASHUNIT_HEADER_ASCII_ART" = "true" ]
}

function bashunit::env::is_simple_output_enabled() {
  [ "$BASHUNIT_SIMPLE_OUTPUT" = "true" ]
}

function bashunit::env::is_stop_on_failure_enabled() {
  [ "$BASHUNIT_STOP_ON_FAILURE" = "true" ]
}

function bashunit::env::is_show_execution_time_enabled() {
  case "$BASHUNIT_SHOW_EXECUTION_TIME" in
  true) return 0 ;;
  auto) ! bashunit::clock::is_expensive ;;
  *) return 1 ;;
  esac
}

# The total "Time taken" footer costs two clock reads per run (negligible), so it
# stays visible in "auto" mode even when per-test timing is skipped; only an
# explicit "false" hides it (#765).
function bashunit::env::is_total_execution_time_enabled() {
  [ "$BASHUNIT_SHOW_EXECUTION_TIME" != "false" ]
}

function bashunit::env::is_dev_mode_enabled() {
  [ -n "$BASHUNIT_DEV_LOG" ]
}

function bashunit::env::is_internal_log_enabled() {
  [ "$BASHUNIT_INTERNAL_LOG" = "true" ]
}

##
# Dev-log writers.
#
# They live next to BASHUNIT_DEV_LOG/BASHUNIT_INTERNAL_LOG and their predicates
# rather than in globals.sh: env.sh is the lowest layer and logs from its own
# source-time code, so keeping the writers here removes the env.sh <-> globals.sh
# call cycle instead of papering over it with a duplicated predicate.
##
function bashunit::current_timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

# shellcheck disable=SC2145
function bashunit::log() {
  if ! bashunit::env::is_dev_mode_enabled; then
    return
  fi

  local level="$1"
  shift

  case "$level" in
  info | INFO) level="INFO" ;;
  debug | DEBUG) level="DEBUG" ;;
  warning | WARNING) level="WARNING" ;;
  critical | CRITICAL) level="CRITICAL" ;;
  error | ERROR) level="ERROR" ;;
  *)
    set -- "$level $@"
    level="INFO"
    ;;
  esac

  echo "$(bashunit::current_timestamp) [$level]: $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >>"$BASHUNIT_DEV_LOG"
}

function bashunit::internal_log() {
  if ! bashunit::env::is_dev_mode_enabled || ! bashunit::env::is_internal_log_enabled; then
    return
  fi

  echo "$(bashunit::current_timestamp) [INTERNAL]: $* #${BASH_SOURCE[1]}:${BASH_LINENO[0]}" >>"$BASHUNIT_DEV_LOG"
}

function bashunit::env::is_verbose_enabled() {
  [ "$BASHUNIT_VERBOSE" = "true" ]
}

function bashunit::env::is_bench_mode_enabled() {
  [ "$BASHUNIT_BENCH_MODE" = "true" ]
}

function bashunit::env::is_no_output_enabled() {
  [ "$BASHUNIT_NO_OUTPUT" = "true" ]
}

function bashunit::env::is_show_skipped_enabled() {
  [ "$BASHUNIT_SHOW_SKIPPED" = "true" ]
}

function bashunit::env::is_show_incomplete_enabled() {
  [ "$BASHUNIT_SHOW_INCOMPLETE" = "true" ]
}

function bashunit::env::is_strict_mode_enabled() {
  [ "$BASHUNIT_STRICT_MODE" = "true" ]
}

function bashunit::env::is_stop_on_assertion_failure_enabled() {
  [ "$BASHUNIT_STOP_ON_ASSERTION_FAILURE" = "true" ]
}

function bashunit::env::is_skip_env_file_enabled() {
  [ "$BASHUNIT_SKIP_ENV_FILE" = "true" ]
}

function bashunit::env::is_login_shell_enabled() {
  [ "$BASHUNIT_LOGIN_SHELL" = "true" ]
}

function bashunit::env::is_failures_only_enabled() {
  [ "$BASHUNIT_FAILURES_ONLY" = "true" ]
}

function bashunit::env::is_show_output_on_failure_enabled() {
  [ "$BASHUNIT_SHOW_OUTPUT_ON_FAILURE" = "true" ]
}

function bashunit::env::is_no_progress_enabled() {
  [ "$BASHUNIT_NO_PROGRESS" = "true" ]
}

function bashunit::env::is_no_color_enabled() {
  [ "$BASHUNIT_NO_COLOR" = "true" ]
}

function bashunit::env::is_diff_enabled() {
  # :- guard: a user (or test) may have unset BASHUNIT_NO_DIFF; a bare read
  # dies under set -u (--strict) (#836)
  [ "${BASHUNIT_NO_DIFF:-}" != "true" ]
}

##
# Whether the current terminal can render ANSI color sequences.
# Returns 1 when TERM=dumb or when `tput colors` reports fewer than 8.
# Returns 0 when tput is missing (assume colors work, preserving prior behavior).
##
function bashunit::env::supports_color() {
  if [ "${TERM:-}" = "dumb" ]; then
    return 1
  fi

  if ! bashunit::dependencies::has_tput; then
    return 0
  fi

  local n
  n=$(tput colors 2>/dev/null)
  case "$n" in
  '' | *[!0-9]*)
    return 0
    ;;
  *)
    [ "$n" -ge 8 ]
    ;;
  esac
}

function bashunit::env::is_coverage_enabled() {
  [ "$BASHUNIT_COVERAGE" = "true" ]
}

function bashunit::env::is_tap_output_enabled() {
  [ "$BASHUNIT_OUTPUT_FORMAT" = "tap" ]
}

function bashunit::env::is_snapshot_report_unused_enabled() {
  [ "$BASHUNIT_SNAPSHOT_REPORT_UNUSED" = "true" ]
}

function bashunit::env::is_snapshot_create_enabled() {
  [ "$BASHUNIT_SNAPSHOT_CREATE" = "true" ]
}

function bashunit::env::is_snapshot_update_enabled() {
  [ "$BASHUNIT_SNAPSHOT_UPDATE" = "true" ]
}

function bashunit::env::is_fail_on_risky_enabled() {
  [ "$BASHUNIT_FAIL_ON_RISKY" = "true" ]
}

function bashunit::env::is_profile_enabled() {
  [ "$BASHUNIT_PROFILE" = "true" ]
}

function bashunit::env::active_internet_connection() {
  if [ "${BASHUNIT_NO_NETWORK:-}" = "true" ]; then
    return 1
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -sfI https://github.com >/dev/null 2>&1 && return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -q --spider https://github.com && return 0
  fi

  if ping -c 1 -W 3 google.com &>/dev/null; then
    return 0
  fi

  return 1
}

function bashunit::env::find_terminal_width() {
  local cols=""

  if command -v tput >/dev/null; then
    cols=$(tput cols 2>/dev/null)
  fi

  if [ -z "$cols" ] && command -v stty >/dev/null; then
    cols=$(stty size 2>/dev/null | cut -d' ' -f2)
  fi

  # Directly echo the value with fallback
  echo "${cols:-100}"
}

function bashunit::env::print_verbose() {
  bashunit::internal_log "Printing verbose environment variables"
  local IFS=$' \t\n'
  # Bash 3.0 compatible: separate declaration and assignment for arrays
  local keys
  keys=(
    "BASHUNIT_DEFAULT_PATH"
    "BASHUNIT_DEV_LOG"
    "BASHUNIT_BOOTSTRAP"
    "BASHUNIT_BOOTSTRAP_ARGS"
    "BASHUNIT_LOG_JUNIT"
    "BASHUNIT_LOG_GHA"
    "BASHUNIT_REPORT_HTML"
    "BASHUNIT_REPORT_TAP"
    "BASHUNIT_PARALLEL_RUN"
    "BASHUNIT_SHOW_HEADER"
    "BASHUNIT_HEADER_ASCII_ART"
    "BASHUNIT_SIMPLE_OUTPUT"
    "BASHUNIT_STOP_ON_FAILURE"
    "BASHUNIT_SHOW_EXECUTION_TIME"
    "BASHUNIT_VERBOSE"
    "BASHUNIT_STRICT_MODE"
    "BASHUNIT_STOP_ON_ASSERTION_FAILURE"
    "BASHUNIT_SKIP_ENV_FILE"
    "BASHUNIT_LOGIN_SHELL"
    "BASHUNIT_COVERAGE"
    "BASHUNIT_COVERAGE_PATHS"
    "BASHUNIT_COVERAGE_EXCLUDE"
    "BASHUNIT_COVERAGE_REPORT"
    "BASHUNIT_COVERAGE_REPORT_HTML"
    "BASHUNIT_COVERAGE_MIN"
    "BASHUNIT_COVERAGE_ENGINE"
  )

  local max_length=0

  local key
  for key in "${keys[@]+"${keys[@]}"}"; do
    if ((${#key} > max_length)); then
      max_length=${#key}
    fi
  done

  for key in "${keys[@]+"${keys[@]}"}"; do
    bashunit::internal_log "$key=${!key}"
    printf "%s:%*s%s\n" "$key" $((max_length - ${#key} + 1)) "" "${!key}"
  done
}

EXIT_CODE_STOP_ON_FAILURE=4
# Use a unique directory per run to avoid conflicts when bashunit is invoked
# recursively or multiple instances are executed in parallel.
TEMP_DIR_PARALLEL_TEST_SUITE="${TMPDIR:-/tmp}/bashunit/parallel/${_BASHUNIT_OS:-Unknown}/$(bashunit::random_str 8)"
TEMP_FILE_PARALLEL_STOP_ON_FAILURE="$TEMP_DIR_PARALLEL_TEST_SUITE/.stop-on-failure"
TERMINAL_WIDTH="$(bashunit::env::find_terminal_width)"
CAT="$(command -v cat)"
GREP="$(command -v grep)"
MKTEMP="$(command -v mktemp)"
AWK="$(command -v awk)"
# Deferred-output scratch files. Each used to be its own `mktemp` fork; at ~258
# nested cold starts in the acceptance suite that is ~1.5k forks and dominates
# cold-start cost (#798). Derive them from one run-unique directory instead:
# `bashunit::random_str` is fork-free and every consumer appends with `>>` (which
# creates the file lazily) or guards reads with `[ -s ... ]`, so the files need
# not be pre-created. The random suffix keeps the directory unique across
# recursive and parallel invocations, matching TEMP_DIR_PARALLEL_TEST_SUITE.
_BASHUNIT_RUN_OUTPUT_DIR="${TMPDIR:-/tmp}/bashunit/run/${_BASHUNIT_OS:-Unknown}/$(bashunit::random_str 8)"
FAILURES_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/failures"
SKIPPED_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/skipped"
INCOMPLETE_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/incomplete"
RISKY_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/risky"
PROFILE_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/profile"
# Prefix for one file-per-worker capture of stderr written inside a parallel
# worker but outside a test body. An ordinal is appended per spawned worker;
# these must not live under TEMP_DIR_PARALLEL_TEST_SUITE, whose every entry is
# walked by state::aggregate_parallel_results (#864).
WORKER_STDERR_OUTPUT_PREFIX="$_BASHUNIT_RUN_OUTPUT_DIR/worker-stderr"
# Collects "<test_file>:<function_name>" for every failing test in a run so the
# next --rerun-failed can replay just those. Shared across parallel subshells.
RERUN_FAILED_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/rerun-failed"
# Collects every snapshot path a test resolved, so --snapshot-report-unused can
# diff it against what is on disk. Appended from the test subshells, only when
# the flag is on, so a normal run pays nothing.
SNAPSHOT_USED_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/snapshots-used"
REPORTS_OUTPUT_PATH="$_BASHUNIT_RUN_OUTPUT_DIR/reports"

# Shared temp directory, initialized once at startup for performance.
BASHUNIT_TEMP_DIR="${TMPDIR:-/tmp}/bashunit/tmp"

##
# Creates both scratch directories in a single `mkdir -p` fork.
#
# This must not fail silently: every deferred-output collector (failures,
# skipped, incomplete, risky, rerun) and every `temp_file`/`temp_dir` call
# writes under these paths, and each of them appends with `>>` or guards reads
# with `[ -s ]`. Without the directories those writes are all no-ops, so a red
# suite would render as a green one — the worst possible failure mode for a
# test runner. Abort with an actionable message instead.
#
# Arguments: $1 run output dir, $2 shared temp dir
# Returns: 0 when both directories exist, 1 otherwise (message on stderr)
##
function bashunit::env::create_scratch_dirs() {
  local run_dir=$1
  local temp_dir=$2

  # `mkdir -p` may race a sibling bashunit on the shared temp dir, so its exit
  # code alone is not conclusive; the postcondition below is what decides. Its
  # stderr is deliberately NOT silenced, so a real failure stays visible.
  mkdir -p "$run_dir" "$temp_dir" || true

  local dir
  for dir in "$run_dir" "$temp_dir"; do
    if [ ! -d "$dir" ]; then
      printf 'bashunit: cannot create the scratch directory: %s\n' "$dir" >&2
      printf 'bashunit: set TMPDIR to a writable location and try again.\n' >&2
      return 1
    fi
  done
}

bashunit::env::create_scratch_dirs "$_BASHUNIT_RUN_OUTPUT_DIR" "$BASHUNIT_TEMP_DIR" || exit 1

# Removes this run's scratch directory (guarded like parallel::cleanup so a
# broken variable can never turn the rm loose elsewhere). Called at the end of
# a run and on SIGINT; without it every invocation leaks one directory.
function bashunit::env::cleanup_run_output_dir() {
  local target="$_BASHUNIT_RUN_OUTPUT_DIR"
  case "$target" in
  */bashunit/run/*)
    rm -rf "$target"
    ;;
  *)
    bashunit::internal_log "env::cleanup_run_output_dir" "refused unsafe path:$target"
    return 1
    ;;
  esac
}

# Cover early-exit paths (--version, --help, doc, init, ...). The test-run path
# replaces this trap in main.sh and calls the cleanup explicitly instead; child
# subshells never inherit EXIT traps, so a parallel worker cannot remove the
# directory mid-run.
trap 'bashunit::env::cleanup_run_output_dir' EXIT

if bashunit::env::is_dev_mode_enabled; then
  bashunit::internal_log "info" "Dev log enabled" "file:$BASHUNIT_DEV_LOG"
fi
