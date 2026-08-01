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

  # Optional bootstrap
  # shellcheck disable=SC1090,SC2086
  [ -f "${BASHUNIT_BOOTSTRAP:-}" ] && source "$BASHUNIT_BOOTSTRAP" ${BASHUNIT_BOOTSTRAP_ARGS:-}

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
