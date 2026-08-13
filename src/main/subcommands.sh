#!/usr/bin/env bash

# Flag parsing for doc, init, learn, watch and upgrade; each delegates to src/cli/ or src/learn/.

function bashunit::main::cmd_doc() {
  local filter=""
  local custom_only=false
  local boot_file="${BASHUNIT_BOOTSTRAP:-}"
  local boot_provided=false

  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      bashunit::console_header::print_doc_help
      exit 0
      ;;
    --custom)
      custom_only=true
      shift
      ;;
    -e | --env | --boot)
      boot_file="${2:-}"
      boot_provided=true
      shift 2
      ;;
    *)
      filter="$1"
      shift
      ;;
    esac
  done

  # Snapshot before sourcing: whatever assert_* appears afterwards is the
  # project's own.
  local known
  known="$(compgen -A function assert_ 2>/dev/null)"

  if [ -n "$boot_file" ]; then
    if [ ! -r "$boot_file" ]; then
      if [ "$boot_provided" = true ]; then
        printf "%sError: cannot read the bootstrap file: '%s'.%s\n" \
          "$_BASHUNIT_COLOR_FAILED" "$boot_file" "$_BASHUNIT_COLOR_DEFAULT" >&2
        exit 1
      fi
    else
      # Two ways this never returns: a syntax error makes `source` return
      # non-zero, which ends the shell because `set -e` is active here, and a
      # bare `exit` in the file ends it regardless. Either way nothing below
      # runs, so the marker is what the EXIT trap reports when it was never
      # cleared (#1181).
      _BASHUNIT_LOADING_BOOTSTRAP="$boot_file"
      # shellcheck disable=SC1090,SC2086
      source "$boot_file" ${BASHUNIT_BOOTSTRAP_ARGS:-}
      _BASHUNIT_LOADING_BOOTSTRAP=""
    fi
  fi

  bashunit::doc::custom_fns_to_slot "$known"

  if [ "$custom_only" = true ]; then
    if ! bashunit::doc::print_custom_asserts "$filter"; then
      printf 'No custom assertions found.\n'
      printf 'Load them with --boot <file> or BASHUNIT_BOOTSTRAP.\n'
    fi
    exit 0
  fi

  bashunit::doc::print_asserts "$filter"

  if [ -n "$_BASHUNIT_DOC_CUSTOM_FNS_OUT" ]; then
    printf '\n## Custom assertions\n\n'
    bashunit::doc::print_custom_asserts "$filter" || true
  fi

  exit 0
}

#############################
# Subcommand: init
#############################
function bashunit::main::cmd_init() {
  case "${1:-}" in
  -h | --help)
    bashunit::console_header::print_init_help
    exit 0
    ;;
  esac

  bashunit::init::project "${1:-}"
  exit 0
}

#############################
# Subcommand: learn
#############################
function bashunit::main::cmd_learn() {
  case "${1:-}" in
  -h | --help)
    bashunit::console_header::print_learn_help
    exit 0
    ;;
  esac

  bashunit::learn::start
  exit 0
}

#############################
# Subcommand: watch
#############################
function bashunit::main::cmd_watch() {
  local path=""
  local -a extra_args=()

  while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help)
      bashunit::console_header::print_watch_help
      exit 0
      ;;
    -f | --filter)
      # Forward the filter flag and its value to the underlying test run
      extra_args[${#extra_args[@]}]="$1"
      shift || true
      if [ $# -gt 0 ]; then
        extra_args[${#extra_args[@]}]="$1"
      fi
      ;;
    -*)
      extra_args[${#extra_args[@]}]="$1"
      ;;
    *)
      if [ -z "$path" ]; then
        path="$1"
      else
        extra_args[${#extra_args[@]}]="$1"
      fi
      ;;
    esac
    shift || true
  done

  [ -z "$path" ] && path="."

  bashunit::watch::run "$path" "${extra_args[@]+"${extra_args[@]}"}"
}

#############################
# Subcommand: upgrade
#############################
function bashunit::main::cmd_upgrade() {
  case "${1:-}" in
  -h | --help)
    bashunit::console_header::print_upgrade_help
    exit 0
    ;;
  esac

  bashunit::upgrade::upgrade
  exit 0
}

#############################
# Subcommand: assert
#############################

# Check if a name corresponds to an assertion function (not a file or command)
