#!/usr/bin/env bash

# Flag parsing for the default 'test' subcommand.

# The argv the suite pre-scan produces, read by cmd_test below.
_BASHUNIT_MAIN_SUITE_ARGV=()

##
# Resolves `--suite <name>` (repeatable) and `--list-suites` before the main
# parse loop and rewrites argv into _BASHUNIT_MAIN_SUITE_ARGV.
#
# The suites' own options are placed FIRST, so a flag the caller typed is
# parsed later and wins -- the documented precedence is
# CLI flags > suite settings > global .bashunitrc > .env > defaults. An
# explicit path argument likewise replaces the suites' paths rather than
# adding to them.
#
# `--list-suites` prints and exits here: it is a query about the config file,
# and nothing below it in the run has anything to add.
##
function bashunit::main::apply_suites() {
  local -a suite_names=()
  local -a rest=()
  local -a cli_paths=()
  local has_suite=false

  while [ $# -gt 0 ]; do
    case "$1" in
    --suite)
      if [ -z "${2:-}" ]; then
        printf "%sError: --suite requires a name.%s\n" \
          "${_BASHUNIT_COLOR_FAILED:-}" "${_BASHUNIT_COLOR_DEFAULT:-}" >&2
        exit 1
      fi
      has_suite=true
      suite_names[${#suite_names[@]}]="$2"
      shift
      ;;
    --list-suites)
      bashunit::suites::load ".bashunitrc"
      bashunit::suites::names
      exit 0
      ;;
    -*)
      rest[${#rest[@]}]="$1"
      ;;
    *)
      cli_paths[${#cli_paths[@]}]="$1"
      rest[${#rest[@]}]="$1"
      ;;
    esac
    shift
  done

  if [ "$has_suite" = false ]; then
    _BASHUNIT_MAIN_SUITE_ARGV=(${rest[@]+"${rest[@]}"})
    return 0
  fi

  bashunit::suites::load ".bashunitrc"

  local -a expanded=()
  local -a suite_paths=()
  local name entry path
  for name in ${suite_names[@]+"${suite_names[@]}"}; do
    bashunit::suites::resolve "$name"
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      expanded[${#expanded[@]}]="$entry"
    done <<EOF
$_BASHUNIT_SUITE_ARGS_OUT
EOF
    for path in $_BASHUNIT_SUITE_PATHS_OUT; do
      suite_paths[${#suite_paths[@]}]="$path"
    done
  done

  # Only when the caller named no path of their own: an explicit path is the
  # more specific instruction, the same way an explicit flag is.
  if [ "${#cli_paths[@]}" -eq 0 ]; then
    for path in ${suite_paths[@]+"${suite_paths[@]}"}; do
      expanded[${#expanded[@]}]="$path"
    done
  fi

  _BASHUNIT_MAIN_SUITE_ARGV=(${expanded[@]+"${expanded[@]}"} ${rest[@]+"${rest[@]}"})
}

function bashunit::main::cmd_test() {
  local filter=""
  local tag_filter=""
  local exclude_tag_filter=""
  local IFS=$' \t\n'
  local -a raw_args=()
  local raw_args_count=0
  local -a args=()
  local args_count=0
  local assert_fn=""
  local _bashunit_coverage_opt_set=false

  # Named suites are resolved into plain flags and paths before anything is
  # parsed, so the loop below never has to know about them.
  bashunit::main::apply_suites "$@"
  set -- ${_BASHUNIT_MAIN_SUITE_ARGV[@]+"${_BASHUNIT_MAIN_SUITE_ARGV[@]}"}

  # Parse test-specific options.
  #
  # Flag branches assign WITHOUT export and strip the export attribute with
  # `export -n`: run-mode flags are this-process-only. Everything that reads
  # them (runner, reporters, parallel workers) runs in this shell or its
  # subshells, which inherit unexported variables — while exec'd children
  # (nested bashunit runs: bashunit's own acceptance suite under
  # `build.sh --verify`, or a user's script under test that calls bashunit)
  # must NOT inherit the parent's flags (#834, #837). The explicit `export -n`
  # also clears an export attribute stamped by an allexport .env load.
  # Pair any newly exported-by-necessity flag with a comment naming the exec'd
  # consumer, and extend tests/acceptance/fixtures/flag_env_leak/leak_probe.sh.
  while [ $# -gt 0 ]; do
    case "$1" in
    -a | --assert)
      # Superseded by the `bashunit assert` subcommand. The help text has said
      # "deprecated" since that subcommand landed without ever warning at
      # runtime, which is how a deprecation stays put forever.
      #
      # Not a pure rename: this path goes through cmd_test's parser, so it also
      # accepts test-level flags (`--env`, `--no-parallel`). `bashunit assert`
      # forwards everything to the assertion instead. Removing this form needs
      # that gap closed first.
      bashunit::env::warn_deprecated "\`bashunit test --assert\`" "\`bashunit assert\`"
      assert_fn="$2"
      shift
      ;;
    -f | --filter)
      filter="$2"
      shift
      ;;
    --exclude-filter)
      if [ -z "$BASHUNIT_EXCLUDE_FILTER" ]; then
        BASHUNIT_EXCLUDE_FILTER="$2"
      else
        BASHUNIT_EXCLUDE_FILTER="$BASHUNIT_EXCLUDE_FILTER,$2"
      fi
      # export -n like every other flag (#839): find_total_tests reads this
      # from a plain subshell, which inherits it without exporting, and a real
      # export would leak into nested ./bashunit runs.
      export -n BASHUNIT_EXCLUDE_FILTER
      shift
      ;;
    --tag)
      bashunit::main::require_valid_tag_expression_or_exit "$2"
      if [ -z "$tag_filter" ]; then
        tag_filter="$2"
      else
        tag_filter="$tag_filter,$2"
      fi
      shift
      ;;
    --exclude-tag)
      if [ -z "$exclude_tag_filter" ]; then
        exclude_tag_filter="$2"
      else
        exclude_tag_filter="$exclude_tag_filter,$2"
      fi
      shift
      ;;
    --sandbox)
      BASHUNIT_SANDBOX=true
      export -n BASHUNIT_SANDBOX
      ;;
    --sandbox-allow)
      # Repeatable and comma separated; both forms end up in one list.
      if [ -z "$BASHUNIT_SANDBOX_ALLOW" ]; then
        BASHUNIT_SANDBOX_ALLOW="$2"
      else
        BASHUNIT_SANDBOX_ALLOW="$BASHUNIT_SANDBOX_ALLOW,$2"
      fi
      export -n BASHUNIT_SANDBOX_ALLOW
      shift
      ;;
    -s | --simple)
      BASHUNIT_SIMPLE_OUTPUT=true
      export -n BASHUNIT_SIMPLE_OUTPUT
      ;;
    --detailed)
      BASHUNIT_SIMPLE_OUTPUT=false
      export -n BASHUNIT_SIMPLE_OUTPUT
      ;;
    --output)
      BASHUNIT_OUTPUT_FORMAT="$2"
      export -n BASHUNIT_OUTPUT_FORMAT
      shift
      ;;
    --debug)
      local output_file="${2:-}"
      if [ -n "$output_file" ] && [ "${output_file:0:1}" != "-" ]; then
        exec >"$output_file" 2>&1
        shift
      fi
      set -x
      ;;
    -S | --stop-on-failure)
      # This-process-only: parallel stop uses a flag file and sync stop uses
      # exit codes, so no child process needs it — exported (including via an
      # allexport .env load, hence export -n) it leaked into nested bashunit
      # runs, aborting them before rerun::persist could write
      # .bashunit/last-failed (broke verify's acceptance tests, #834).
      BASHUNIT_STOP_ON_FAILURE=true
      export -n BASHUNIT_STOP_ON_FAILURE
      ;;
    -p | --parallel)
      BASHUNIT_PARALLEL_RUN=true
      export -n BASHUNIT_PARALLEL_RUN
      ;;
    -j | --jobs)
      BASHUNIT_PARALLEL_RUN=true
      export -n BASHUNIT_PARALLEL_RUN
      # "auto" caps at the detected core count; wait_for_job_slot needs an
      # integer, so resolve it here rather than leaking the string downstream.
      if [ "$2" = "auto" ]; then
        BASHUNIT_PARALLEL_JOBS="$(bashunit::check_os::nproc)"
        export -n BASHUNIT_PARALLEL_JOBS
      else
        BASHUNIT_PARALLEL_JOBS="$2"
        export -n BASHUNIT_PARALLEL_JOBS
      fi
      shift
      ;;
    --no-parallel)
      BASHUNIT_PARALLEL_RUN=false
      export -n BASHUNIT_PARALLEL_RUN
      ;;
    --test-timeout)
      BASHUNIT_TEST_TIMEOUT="$2"
      export -n BASHUNIT_TEST_TIMEOUT
      shift
      ;;
    --retry)
      BASHUNIT_RETRY="$2"
      export -n BASHUNIT_RETRY
      shift
      ;;
    --repeat)
      BASHUNIT_REPEAT="$2"
      export -n BASHUNIT_REPEAT
      shift
      ;;
    --random-order)
      BASHUNIT_RANDOM_ORDER=true
      export -n BASHUNIT_RANDOM_ORDER
      ;;
    --order-by)
      BASHUNIT_ORDER_BY="$2"
      export -n BASHUNIT_ORDER_BY
      shift
      ;;
    --seed)
      BASHUNIT_SEED="$2"
      export -n BASHUNIT_SEED
      shift
      ;;
    --shard)
      bashunit::main::set_shard_or_exit "$2"
      shift
      ;;
    --rerun-failed)
      BASHUNIT_RERUN_FAILED=true
      export -n BASHUNIT_RERUN_FAILED
      ;;
    --changed)
      BASHUNIT_CHANGED=true
      export -n BASHUNIT_CHANGED
      # The ref is optional, so $2 is only taken when it cannot be the run's path
      # argument: an existing path there is a path, never a ref. A ref that also
      # names a file on disk has to be written as `--changed ./main` or set
      # through BASHUNIT_CHANGED_REF.
      if [ -n "${2:-}" ] && [ "${2#-}" = "${2:-}" ] && [ ! -e "$2" ]; then
        BASHUNIT_CHANGED_REF="$2"
        export -n BASHUNIT_CHANGED_REF
        shift
      fi
      ;;
    --list | --dry-run)
      BASHUNIT_LIST_TESTS=true
      export -n BASHUNIT_LIST_TESTS
      ;;
    --list-format)
      BASHUNIT_LIST_FORMAT="$2"
      export -n BASHUNIT_LIST_FORMAT
      shift
      ;;
    --snapshot-update)
      BASHUNIT_SNAPSHOT_UPDATE=true
      export -n BASHUNIT_SNAPSHOT_UPDATE
      ;;
    --no-snapshot-create)
      BASHUNIT_SNAPSHOT_CREATE=false
      export -n BASHUNIT_SNAPSHOT_CREATE
      ;;
    --snapshot-prune)
      BASHUNIT_SNAPSHOT_PRUNE=true
      export -n BASHUNIT_SNAPSHOT_PRUNE
      ;;
    --snapshot-report-unused)
      BASHUNIT_SNAPSHOT_REPORT_UNUSED=true
      export -n BASHUNIT_SNAPSHOT_REPORT_UNUSED
      ;;
    -w | --watch)
      BASHUNIT_WATCH_MODE=true
      export -n BASHUNIT_WATCH_MODE
      ;;
    -e | --env | --boot)
      # Support: --env "bootstrap.sh arg1 arg2"
      local boot_file="${2%% *}"
      local boot_args="${2#* }"
      if [ "$boot_args" != "$2" ]; then
        BASHUNIT_BOOTSTRAP_ARGS="$boot_args"
        export -n BASHUNIT_BOOTSTRAP_ARGS
      fi
      # A missing bootstrap used to leak a raw `source` error, abort the rest of
      # the parse and exit 0 with no tests run at all (#875).
      if [ ! -f "$boot_file" ] || [ ! -r "$boot_file" ]; then
        printf "%sError: cannot read the bootstrap file: '%s'.%s\n" \
          "${_BASHUNIT_COLOR_FAILED}" "$boot_file" "${_BASHUNIT_COLOR_DEFAULT}" >&2
        exit 1
      fi
      # Export all variables from the env file so they're available in subshells
      # (e.g., process substitution used in load_test_files)
      set -o allexport
      # shellcheck disable=SC1090,SC2086
      source "$boot_file" ${BASHUNIT_BOOTSTRAP_ARGS:-}
      set +o allexport
      shift
      ;;
    # Report flags are this-process-only: reports are generated by the main
    # shell after aggregation, no child process reads these. `export -n` also
    # strips an export attribute inherited from an allexport .env load —
    # otherwise nested bashunit runs (bashunit's own acceptance tests, or a
    # user's scripts under test that call bashunit) silently write their own
    # reports over the parent's files and blow the per-run fork budget (#834).
    --log-junit | --report-junit)
      BASHUNIT_LOG_JUNIT="$2"
      export -n BASHUNIT_LOG_JUNIT
      shift
      ;;
    --log-gha)
      BASHUNIT_LOG_GHA="$2"
      export -n BASHUNIT_LOG_GHA
      shift
      ;;
    --gha-annotations)
      BASHUNIT_GHA_ANNOTATIONS="$2"
      export -n BASHUNIT_GHA_ANNOTATIONS
      shift
      ;;
    -r | --report-html)
      BASHUNIT_REPORT_HTML="$2"
      export -n BASHUNIT_REPORT_HTML
      shift
      ;;
    --report-tap)
      BASHUNIT_REPORT_TAP="$2"
      export -n BASHUNIT_REPORT_TAP
      shift
      ;;
    --report-md)
      BASHUNIT_REPORT_MD="$2"
      export -n BASHUNIT_REPORT_MD
      shift
      ;;
    --report-json)
      BASHUNIT_REPORT_JSON="$2"
      export -n BASHUNIT_REPORT_JSON
      shift
      ;;
    --no-output)
      BASHUNIT_NO_OUTPUT=true
      export -n BASHUNIT_NO_OUTPUT
      ;;
    -vvv | --verbose)
      BASHUNIT_VERBOSE=true
      export -n BASHUNIT_VERBOSE
      ;;
    -h | --help)
      bashunit::console_header::print_test_help
      exit 0
      ;;
    --show-skipped)
      BASHUNIT_SHOW_SKIPPED=true
      export -n BASHUNIT_SHOW_SKIPPED
      ;;
    --show-incomplete)
      BASHUNIT_SHOW_INCOMPLETE=true
      export -n BASHUNIT_SHOW_INCOMPLETE
      ;;
    --failures-only)
      BASHUNIT_FAILURES_ONLY=true
      export -n BASHUNIT_FAILURES_ONLY
      ;;
    --fail-on-risky)
      BASHUNIT_FAIL_ON_RISKY=true
      export -n BASHUNIT_FAIL_ON_RISKY
      ;;
    --fail-on-flaky)
      BASHUNIT_FAIL_ON_FLAKY=true
      export -n BASHUNIT_FAIL_ON_FLAKY
      ;;
    --profile)
      BASHUNIT_PROFILE=true
      export -n BASHUNIT_PROFILE
      ;;
    --show-output)
      BASHUNIT_SHOW_OUTPUT_ON_FAILURE=true
      export -n BASHUNIT_SHOW_OUTPUT_ON_FAILURE
      ;;
    --no-output-on-failure)
      BASHUNIT_SHOW_OUTPUT_ON_FAILURE=false
      export -n BASHUNIT_SHOW_OUTPUT_ON_FAILURE
      ;;
    --no-progress)
      BASHUNIT_NO_PROGRESS=true
      export -n BASHUNIT_NO_PROGRESS
      ;;
    --strict)
      BASHUNIT_STRICT_MODE=true
      export -n BASHUNIT_STRICT_MODE
      ;;
    -R | --run-all)
      BASHUNIT_STOP_ON_ASSERTION_FAILURE=false
      export -n BASHUNIT_STOP_ON_ASSERTION_FAILURE
      ;;
    --skip-env-file)
      BASHUNIT_SKIP_ENV_FILE=true
      export -n BASHUNIT_SKIP_ENV_FILE
      ;;
    -l | --login)
      BASHUNIT_LOGIN_SHELL=true
      export -n BASHUNIT_LOGIN_SHELL
      ;;
    --no-color)
      # shellcheck disable=SC2034
      BASHUNIT_NO_COLOR=true
      ;;
    --coverage)
      # Don't export - prevents nested bashunit runs from inheriting coverage
      # shellcheck disable=SC2034
      BASHUNIT_COVERAGE=true
      ;;
    --coverage-paths)
      # shellcheck disable=SC2034
      BASHUNIT_COVERAGE_PATHS="$2"
      shift
      ;;
    --coverage-exclude)
      # shellcheck disable=SC2034
      BASHUNIT_COVERAGE_EXCLUDE="$2"
      shift
      ;;
    --coverage-report)
      # The value is optional, matching --coverage-report-html below and the
      # `[file]` notation the docs use. Reading "$2" unconditionally aborted the
      # run with `$2: unbound variable`, or took a following flag as the path.
      # shellcheck disable=SC2034
      case "${2:-}" in
      '' | -*)
        BASHUNIT_COVERAGE_REPORT="$_BASHUNIT_DEFAULT_COVERAGE_REPORT"
        ;;
      *)
        BASHUNIT_COVERAGE_REPORT="$2"
        shift
        ;;
      esac
      _bashunit_coverage_opt_set=true
      ;;
    --coverage-min)
      # shellcheck disable=SC2034
      BASHUNIT_COVERAGE_MIN="$2"
      _bashunit_coverage_opt_set=true
      shift
      ;;
    --coverage-diff)
      # The base ref is required rather than defaulted: an optional value would
      # make `--coverage-diff tests/` swallow the path as a ref.
      # shellcheck disable=SC2034
      BASHUNIT_COVERAGE_DIFF="$2"
      _bashunit_coverage_opt_set=true
      shift
      ;;
    --no-coverage-report)
      # shellcheck disable=SC2034
      BASHUNIT_COVERAGE_REPORT=""
      ;;
    --coverage-report-html)
      # shellcheck disable=SC2034
      # Use default if no value provided or next arg is a flag
      if [ -z "${2:-}" ]; then
        BASHUNIT_COVERAGE_REPORT_HTML="coverage/html"
      else
        case "${2:-}" in
        -*)
          BASHUNIT_COVERAGE_REPORT_HTML="coverage/html"
          ;;
        *)
          BASHUNIT_COVERAGE_REPORT_HTML="$2"
          shift
          ;;
        esac
      fi
      _bashunit_coverage_opt_set=true
      ;;
    --coverage-report-cobertura)
      # shellcheck disable=SC2034
      # Use default if no value provided or next arg is a flag
      if [ -z "${2:-}" ]; then
        BASHUNIT_COVERAGE_REPORT_COBERTURA="coverage/cobertura.xml"
      else
        case "${2:-}" in
        -*)
          BASHUNIT_COVERAGE_REPORT_COBERTURA="coverage/cobertura.xml"
          ;;
        *)
          BASHUNIT_COVERAGE_REPORT_COBERTURA="$2"
          shift
          ;;
        esac
      fi
      _bashunit_coverage_opt_set=true
      ;;
    -*)
      # Anything option-shaped reaching here matched no branch above. It used to
      # be filed under test paths, so a typo degraded the run silently and still
      # exited 0: `--parralel` ran sequentially, `--filterr x` ran the whole
      # suite (#871). Test paths never start with a dash.
      bashunit::main::abort_unknown_option "$1" "test"
      ;;
    *)
      raw_args[raw_args_count]="$1"
      raw_args_count=$((raw_args_count + 1))
      ;;
    esac
    shift
  done

  bashunit::main::validate_config_or_exit

  # Auto-enable coverage when any coverage output option is specified
  if [ "$_bashunit_coverage_opt_set" = true ]; then
    # shellcheck disable=SC2034
    BASHUNIT_COVERAGE=true
  fi

  # Expand positional arguments and extract inline filters
  # Skip filter parsing for assert mode - args are not file paths
  local inline_filter=""
  local inline_filter_file=""
  if [ "$raw_args_count" -gt 0 ]; then
    if [ -n "$assert_fn" ]; then
      # Assert mode: pass args as-is without file path processing
      args=("${raw_args[@]}")
      args_count="$raw_args_count"
    else
      # Test mode: process file paths and extract inline filters
      local arg
      for arg in "${raw_args[@]+"${raw_args[@]}"}"; do
        local parsed_path parsed_filter
        {
          read -r parsed_path
          read -r parsed_filter
        } < <(bashunit::helper::parse_file_path_filter "$arg")

        # If an inline filter was found, store it
        if [ -n "$parsed_filter" ]; then
          inline_filter="$parsed_filter"
          inline_filter_file="$parsed_path"
        fi

        local file
        while IFS= read -r file; do
          args[args_count]="$file"
          args_count=$((args_count + 1))
        done < <(bashunit::helper::find_files_recursive "$parsed_path" '*[tT]est.sh')
      done

      # Resolve line number filter to function name
      case "$inline_filter" in
      "__line__:"*)
        local line_number="${inline_filter#__line__:}"
        local resolved_file="${inline_filter_file}"

        # If the file path was a pattern, use the first resolved file
        if [ "$args_count" -gt 0 ]; then
          resolved_file="${args[0]}"
        fi

        inline_filter=$(bashunit::helper::find_function_at_line "$resolved_file" "$line_number")
        if [ -z "$inline_filter" ]; then
          printf "%sError: No test function found at line %s in %s%s\n" \
            "${_BASHUNIT_COLOR_FAILED}" "$line_number" "$resolved_file" "${_BASHUNIT_COLOR_DEFAULT}"
          exit 1
        fi
        ;;
      esac

      # Use inline filter if no -f filter was provided
      if [ -z "$filter" ] && [ -n "$inline_filter" ]; then
        filter="$inline_filter"
      fi
    fi
  fi

  # A run that executes a subset resolves a subset of the snapshots, so every
  # snapshot the subset skipped would be reported as unused. Refusing beats
  # printing a list that invites deleting live files.
  if bashunit::env::is_snapshot_report_unused_enabled ||
    bashunit::env::is_snapshot_prune_enabled; then
    local _snapshot_flag="--snapshot-report-unused"
    if bashunit::env::is_snapshot_prune_enabled; then
      _snapshot_flag="--snapshot-prune"
    fi
    local _partial_flag=""
    [ -n "$filter" ] && _partial_flag="--filter"
    [ -n "$tag_filter" ] && _partial_flag="--tag"
    [ -n "$exclude_tag_filter" ] && _partial_flag="--exclude-tag"
    [ -n "${BASHUNIT_SHARD_INDEX:-}" ] && _partial_flag="--shard"
    bashunit::rerun::is_enabled && _partial_flag="--rerun-failed"
    bashunit::env::is_changed_enabled && _partial_flag="--changed"
    if [ -n "$_partial_flag" ]; then
      printf "%sError: %s needs a full run; %s only runs a subset.%s\n" \
        "${_BASHUNIT_COLOR_FAILED}" "$_snapshot_flag" "$_partial_flag" \
        "${_BASHUNIT_COLOR_DEFAULT}" >&2
      exit 1
    fi
  fi

  # --rerun-failed: restrict discovery to the files recorded as failing last
  # run. Function-level filtering happens in the runner; --filter/--tag still
  # apply on top. With no recorded failures, fall back to the full suite.
  if [ -z "$assert_fn" ] && bashunit::rerun::is_enabled; then
    bashunit::rerun::load
    if bashunit::rerun::has_entries; then
      local -a _rerun_files=()
      local _rerun_file
      while IFS= read -r _rerun_file; do
        [ -z "$_rerun_file" ] && continue
        # Skip entries pointing at deleted files, don't crash.
        [ -f "$_rerun_file" ] || continue
        _rerun_files[${#_rerun_files[@]}]="$_rerun_file"
      done < <(bashunit::rerun::files)
      if [ "${#_rerun_files[@]}" -gt 0 ]; then
        args=("${_rerun_files[@]}")
        args_count=${#args[@]}
      fi
    else
      printf "%sNo previously failing tests recorded; running the full suite.%s\n" \
        "${_BASHUNIT_COLOR_SKIPPED}" "${_BASHUNIT_COLOR_DEFAULT}"
    fi
  fi

  # Optional bootstrap
  # shellcheck disable=SC1090,SC2086
  [ -f "${BASHUNIT_BOOTSTRAP:-}" ] && source "$BASHUNIT_BOOTSTRAP" ${BASHUNIT_BOOTSTRAP_ARGS:-}

  if [ "${BASHUNIT_NO_OUTPUT:-false}" = true ]; then
    exec >/dev/null 2>&1
  fi

  # Disable strict mode for test execution to allow:
  # - Empty array expansion (set +u)
  # - Non-zero exit codes from failing tests (set +e)
  # - Pipe failures in test output (set +o pipefail)
  set +euo pipefail
  if [ -n "$assert_fn" ]; then
    # Disable coverage for assert mode - it's meant for running single assertions,
    # not tracking code coverage. This also prevents issues when parent bashunit
    # runs with coverage and calls subprocess bashunit with -a flag.
    BASHUNIT_COVERAGE=false
    export -n BASHUNIT_COVERAGE
    bashunit::main::exec_assert "$assert_fn" ${args+"${args[@]}"}
  else
    if [ "${BASHUNIT_WATCH_MODE:-false}" = true ]; then
      bashunit::main::watch_loop \
        "$filter" "$tag_filter" "$exclude_tag_filter" \
        ${args+"${args[@]}"}
    else
      if [ "$args_count" -gt 0 ]; then
        bashunit::main::exec_tests \
          "$filter" "$tag_filter" "$exclude_tag_filter" \
          "${args[@]}"
      else
        bashunit::main::exec_tests \
          "$filter" "$tag_filter" "$exclude_tag_filter"
      fi
    fi
  fi
}

#############################
# Subcommand: bench
#############################
