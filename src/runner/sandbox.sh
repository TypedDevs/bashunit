#!/usr/bin/env bash

# --sandbox: fail a test that reaches an external command it did not mock.
#
# Two layers, for the reasons recorded in adrs/adr-012-sandbox-mode.md:
#
#   1. A shell function per blocked command, defined once in the main shell.
#      Functions are resolved before PATH, so a direct call lands in ours: it
#      records the violation in a file the runner reads, prints a message that
#      names the command, and returns 127. This is what makes the failure
#      precise, locale-independent and immune to the test redirecting stderr.
#      A mock is itself a function, so mocking simply replaces the shim.
#
#   2. PATH narrowed, inside the capture subshell, to a directory of symlinks
#      to the allowed commands. Layer 1 cannot follow a test into a child
#      process (`bash -c 'curl …'`); the environment does.
#
# The allowlist is what bashunit itself shells out to while a test runs -- the
# goal is to constrain the test body, not to break the framework -- plus
# whatever --sandbox-allow adds.

# Kept in the same order as the docs table so the two can be diffed by eye.
_BASHUNIT_SANDBOX_BASELINE="awk sed grep cat cut tr sort uniq head tail wc
date mktemp mkdir rm rmdir mv cp ln touch chmod stat find dirname basename
base64 cksum od diff sleep env printf test true false expr id getconf
bc perl python3 uname tput git kill ps sh bash"

_BASHUNIT_SANDBOX_DIR=""
# Per-test file the shims append to; set by the runner before each test.
_BASHUNIT_SANDBOX_VIOLATION_FILE=""
_BASHUNIT_SANDBOX_VIOLATION_SEQ=0
_BASHUNIT_SANDBOX_ALLOWED=""
# Space-delimited list of shell builtins, filled by prepare. A builtin named
# like an executable (echo, printf, test, read, kill) must never be shimmed:
# the function would shadow the builtin for the framework as well, and the
# sandbox is about external commands.
_BASHUNIT_SANDBOX_BUILTINS=""

##
# The allowed set as a space-delimited string, baseline plus --sandbox-allow.
##
function bashunit::sandbox::_allowed_list() {
  local allowed="$_BASHUNIT_SANDBOX_BASELINE"
  if [ -n "${BASHUNIT_SANDBOX_ALLOW:-}" ]; then
    # The flag is repeatable and comma separated; both forms arrive as one list.
    allowed="$allowed $(printf '%s' "$BASHUNIT_SANDBOX_ALLOW" | tr ',' ' ')"
  fi
  # Normalise the newlines in the baseline literal into single spaces.
  printf ' %s ' "$(printf '%s' "$allowed" | tr '\n' ' ')"
}

##
# Whether a command stays reachable under the sandbox.
# Arguments: $1 - command name
##
function bashunit::sandbox::is_allowed() {
  case "$_BASHUNIT_SANDBOX_ALLOWED" in
  *" $1 "*) return 0 ;;
  esac
  return 1
}

##
# Defines the blocking function for one command, unless it is allowed.
# Arguments: $1 - command name
##
function bashunit::sandbox::shim() {
  local name=$1

  case "$name" in
  '' | *[!A-Za-z0-9_.+-]*) return 0 ;;
  esac
  case "$_BASHUNIT_SANDBOX_BUILTINS" in
  *" $name "*) return 0 ;;
  esac
  bashunit::sandbox::is_allowed "$name" && return 0

  eval "function $name() { bashunit::sandbox::blocked '$name'; }"
}

##
# Puts the shim back after a mock for that command is removed. Without it,
# `bashunit::unmock curl` inside a sandboxed test would hand the test the real
# curl -- the opposite of what removing a double should mean.
# Arguments: $1 - command name
##
function bashunit::sandbox::restore_shim() {
  bashunit::env::is_sandbox_enabled || return 0
  bashunit::sandbox::shim "$1"
}

##
# What a blocked command does: record it where the runner will find it however
# the test redirects its output, say so, and answer with the shell's own code
# for "could not find it".
# Arguments: $1 - command name
##
function bashunit::sandbox::blocked() {
  local name=$1

  if [ -n "$_BASHUNIT_SANDBOX_VIOLATION_FILE" ]; then
    printf '%s\n' "$name" >>"$_BASHUNIT_SANDBOX_VIOLATION_FILE" 2>/dev/null || true
  fi

  bashunit::sandbox::violation_message "$name" >&2
  return 127
}

##
# The failure message for a blocked command.
# Arguments: $1 - command
##
function bashunit::sandbox::violation_message() {
  printf "Sandbox: '%s' is not mocked and not allowed. %s\n" \
    "$1" "Mock it with bashunit::mock, or run with --sandbox-allow $1."
}

##
# Builds both layers, once per run, in the main shell: the symlink directory
# PATH will point at, and a blocking function for every executable currently
# reachable through PATH that the run does not allow.
#
# Enumerating PATH costs no fork (globs and builtins only) and takes ~50ms for
# the ~1800 entries of a developer machine, which only a --sandbox run pays.
##
function bashunit::sandbox::prepare() {
  bashunit::env::is_sandbox_enabled || return 0

  _BASHUNIT_SANDBOX_ALLOWED=$(bashunit::sandbox::_allowed_list)
  # compgen is a builtin, so the whole list costs no fork.
  _BASHUNIT_SANDBOX_BUILTINS=" $(compgen -b | tr '\n' ' ') "

  local dir="${_BASHUNIT_RUN_OUTPUT_DIR:-${BASHUNIT_TEMP_DIR:-${TMPDIR:-/tmp}}}/sandbox"
  mkdir -p "$dir" 2>/dev/null || return 0
  _BASHUNIT_SANDBOX_DIR="$dir"
  export _BASHUNIT_SANDBOX_DIR

  local entry name target
  local path_dir
  local IFS=':'
  for path_dir in $PATH; do
    [ -n "$path_dir" ] || continue
    [ -d "$path_dir" ] || continue
    for entry in "$path_dir"/*; do
      [ -f "$entry" ] || continue
      [ -x "$entry" ] || continue
      name=${entry##*/}
      if bashunit::sandbox::is_allowed "$name"; then
        if [ ! -e "$dir/$name" ]; then
          ln -s "$entry" "$dir/$name" 2>/dev/null || true
        fi
        continue
      fi
      bashunit::sandbox::shim "$name"
    done
  done

  # An allowed command that PATH does not currently reach (a shell builtin, or
  # one this machine simply lacks) needs no link; `command -v` settles it
  # without another directory walk.
  unset IFS
  for name in $_BASHUNIT_SANDBOX_ALLOWED; do
    [ -e "$dir/$name" ] && continue
    target=$(command -v "$name" 2>/dev/null) || continue
    case "$target" in
    /*) ln -s "$target" "$dir/$name" 2>/dev/null || true ;;
    esac
  done
}

##
# Points the test at the per-test violation file and narrows PATH. Called
# inside the capture subshell, so the main shell keeps its own PATH.
##
function bashunit::sandbox::activate() {
  bashunit::env::is_sandbox_enabled || return 0
  [ -n "$_BASHUNIT_SANDBOX_DIR" ] || return 0

  PATH="$_BASHUNIT_SANDBOX_DIR"
  export PATH
}

##
# Names the per-test violation file, before the test runs. The name needs no
# fork: the parent's pid plus a counter is unique per test in both run modes,
# and every worker inherits the value its parent set for it.
##
function bashunit::sandbox::begin_test() {
  bashunit::env::is_sandbox_enabled || return 0
  [ -n "$_BASHUNIT_SANDBOX_DIR" ] || return 0

  _BASHUNIT_SANDBOX_VIOLATION_SEQ=$((_BASHUNIT_SANDBOX_VIOLATION_SEQ + 1))
  _BASHUNIT_SANDBOX_VIOLATION_FILE="$_BASHUNIT_SANDBOX_DIR/violation-$$-$_BASHUNIT_SANDBOX_VIOLATION_SEQ"
  export _BASHUNIT_SANDBOX_VIOLATION_FILE
  rm -f "$_BASHUNIT_SANDBOX_VIOLATION_FILE" 2>/dev/null || true
}

##
# Whether the running test has been blocked from a command, without consuming
# the record. Called inside the capture subshell: forcing the test's exit code
# to 127 there is what carries the verdict across the fork, since a --parallel
# worker's counters never reach the parent -- only its encoded payload does.
##
function bashunit::sandbox::peek_violation() {
  bashunit::env::is_sandbox_enabled || return 1
  [ -n "$_BASHUNIT_SANDBOX_VIOLATION_FILE" ] || return 1
  [ -s "$_BASHUNIT_SANDBOX_VIOLATION_FILE" ]
}

##
# The command the test being finished was blocked from running, into
# _BASHUNIT_SANDBOX_COMMAND_OUT. Returns 1 when there was none.
##
_BASHUNIT_SANDBOX_COMMAND_OUT=""
function bashunit::sandbox::violation_of_test() {
  _BASHUNIT_SANDBOX_COMMAND_OUT=""

  bashunit::env::is_sandbox_enabled || return 1
  [ -n "$_BASHUNIT_SANDBOX_VIOLATION_FILE" ] || return 1
  [ -s "$_BASHUNIT_SANDBOX_VIOLATION_FILE" ] || return 1

  local first=""
  while IFS= read -r first; do
    [ -n "$first" ] && break
  done <"$_BASHUNIT_SANDBOX_VIOLATION_FILE"
  rm -f "$_BASHUNIT_SANDBOX_VIOLATION_FILE" 2>/dev/null || true

  [ -n "$first" ] || return 1
  _BASHUNIT_SANDBOX_COMMAND_OUT=$first
  return 0
}
