#!/usr/bin/env bash

# Flag parsing for the 'bench' subcommand.

function bashunit::main::cmd_bench() {
  local filter=""
  local IFS=$' \t\n'
  local -a raw_args=()
  local raw_args_count=0
  local -a args=()
  local args_count=0

  BASHUNIT_BENCH_MODE=true
  export -n BASHUNIT_BENCH_MODE

  # Parse bench-specific options
  while [ $# -gt 0 ]; do
    case "$1" in
    -f | --filter)
      filter="$2"
      shift
      ;;
    --baseline)
      BASHUNIT_BENCH_BASELINE="$2"
      export -n BASHUNIT_BENCH_BASELINE
      shift
      ;;
    --baseline-tolerance)
      BASHUNIT_BENCH_BASELINE_TOLERANCE="$2"
      export -n BASHUNIT_BENCH_BASELINE_TOLERANCE
      case "$BASHUNIT_BENCH_BASELINE_TOLERANCE" in
      '' | *[!0-9.]*)
        printf "%sError: --baseline-tolerance expects a percentage, got '%s'.%s\n" \
          "${_BASHUNIT_COLOR_FAILED}" "$2" "${_BASHUNIT_COLOR_DEFAULT}" >&2
        exit 1
        ;;
      esac
      shift
      ;;
    --baseline-update)
      BASHUNIT_BENCH_BASELINE_UPDATE="$2"
      export -n BASHUNIT_BENCH_BASELINE_UPDATE
      bashunit::main::require_writable_path_or_exit \
        "$BASHUNIT_BENCH_BASELINE_UPDATE" "BASHUNIT_BENCH_BASELINE_UPDATE"
      shift
      ;;
    --report-json)
      BASHUNIT_BENCH_REPORT_JSON="$2"
      export -n BASHUNIT_BENCH_REPORT_JSON
      # require_writable_path_or_exit, not the creatable variant: these writers
      # do not mkdir their directory, and the creatable check rejects a target
      # that already exists (its ancestor walk stops on the file itself).
      bashunit::main::require_writable_path_or_exit \
        "$BASHUNIT_BENCH_REPORT_JSON" "BASHUNIT_BENCH_REPORT_JSON"
      shift
      ;;
    --report-junit)
      BASHUNIT_BENCH_REPORT_JUNIT="$2"
      export -n BASHUNIT_BENCH_REPORT_JUNIT
      bashunit::main::require_writable_path_or_exit \
        "$BASHUNIT_BENCH_REPORT_JUNIT" "BASHUNIT_BENCH_REPORT_JUNIT"
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
        bashunit::main::report_unreadable_bootstrap "$boot_file" "$2"
      fi
      # Export all variables from the env file so they're available in subshells
      # (e.g., process substitution used in load_test_files)
      set -o allexport
      # Two ways this never returns: a syntax error makes `source` return
      # non-zero, which ends the shell because `set -e` is active here, and a
      # bare `exit` in the file ends it regardless. Either way nothing below
      # runs, so the marker is what the EXIT trap reports when it was never
      # cleared (#1181).
      _BASHUNIT_LOADING_BOOTSTRAP="$boot_file"
      # shellcheck disable=SC1090,SC2086
      source "$boot_file" ${BASHUNIT_BOOTSTRAP_ARGS:-}
      _BASHUNIT_LOADING_BOOTSTRAP=""
      set +o allexport
      shift
      ;;
    -vvv | --verbose)
      BASHUNIT_VERBOSE=true
      export -n BASHUNIT_VERBOSE
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
    -h | --help)
      bashunit::console_header::print_bench_help
      exit 0
      ;;
    -*)
      bashunit::main::abort_unknown_option "$1" "bench"
      ;;
    *)
      raw_args[raw_args_count]="$1"
      raw_args_count=$((raw_args_count + 1))
      ;;
    esac
    shift
  done

  # Expand positional arguments
  if [ "$raw_args_count" -gt 0 ]; then
    local arg file
    for arg in "${raw_args[@]+"${raw_args[@]}"}"; do
      while IFS= read -r file; do
        args[args_count]="$file"
        args_count=$((args_count + 1))
      done < <(bashunit::helper::find_files_recursive "$arg" '*[bB]ench.sh')
    done
  fi

  # Optional bootstrap. Absent is fine -- BASHUNIT_BOOTSTRAP defaults to
  # tests/bootstrap.sh, which most projects do not have. Present but broken is
  # not: `[ -f ] && source` swallowed the failure, so a bootstrap with a syntax
  # error left the run with no tests, no summary and exit 0, and CI passed
  # having executed nothing (#1179).
  if [ -f "${BASHUNIT_BOOTSTRAP:-}" ]; then
    # Two ways this never returns: a syntax error makes `source` return
    # non-zero, which ends the shell because `set -e` is active here, and a
    # bare `exit` in the file ends it regardless. Either way nothing below
    # runs, so the marker is what the EXIT trap reports when it was never
    # cleared (#1179).
    _BASHUNIT_LOADING_BOOTSTRAP="$BASHUNIT_BOOTSTRAP"
    # shellcheck disable=SC1090,SC2086
    source "$BASHUNIT_BOOTSTRAP" ${BASHUNIT_BOOTSTRAP_ARGS:-}
    _BASHUNIT_LOADING_BOOTSTRAP=""
  fi

  set +euo pipefail

  # Bash 3.0 compatible: only pass args if we have files
  if [ "$args_count" -gt 0 ]; then
    bashunit::main::exec_benchmarks "$filter" "${args[@]}"
  else
    bashunit::main::exec_benchmarks "$filter"
  fi
}

#############################
# Subcommand: doc
#############################
