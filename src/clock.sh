#!/usr/bin/env bash

_BASHUNIT_CLOCK_NOW_IMPL=""

function bashunit::clock::_choose_impl() {
  local shell_time
  # Use explicit indices for Bash 3.0 compatibility (empty array access fails with set -u)
  local attempts_count=0
  local attempts

  # 1. Try native shell EPOCHREALTIME (fastest - no subprocess, Bash 5.0+)
  attempts[attempts_count]="EPOCHREALTIME"
  attempts_count=$((attempts_count + 1))
  if shell_time="$(bashunit::clock::shell_time)"; then
    _BASHUNIT_CLOCK_NOW_IMPL="shell"
    return 0
  fi

  # 2. Unix date +%s%N (no subprocess overhead on supported systems)
  attempts[attempts_count]="date"
  attempts_count=$((attempts_count + 1))
  if ! bashunit::check_os::is_macos && ! bashunit::check_os::is_alpine; then
    local result
    result=$(date +%s%N 2>/dev/null)
    # A pure-digit result means %N expanded; a literal "N" (unsupported date)
    # contains a non-digit, so the digits-only check alone is sufficient.
    case "$result" in
    '' | *[!0-9]*) ;;
    *)
      _BASHUNIT_CLOCK_NOW_IMPL="date"
      return 0
      ;;
    esac
  fi

  # 3. Try Perl with Time::HiRes. Probe by reading the actual time (not an empty
  # `-e ""`) so the pending first read reuses this fork instead of paying a
  # second one; a non-digit/empty result means perl or Time::HiRes is missing, so
  # fall through. The value is seeded into the return slot for now_to_slot.
  attempts[attempts_count]="Perl"
  attempts_count=$((attempts_count + 1))
  if bashunit::dependencies::has_perl; then
    local perl_now
    perl_now="$(perl -MTime::HiRes -e 'printf("%.0f\n", Time::HiRes::time() * 1000000000)' 2>/dev/null)"
    case "$perl_now" in
    '' | *[!0-9]*) ;;
    *)
      _BASHUNIT_CLOCK_NOW_IMPL="perl"
      _BASHUNIT_CLOCK_NOW_OUT="$perl_now"
      return 0
      ;;
    esac
  fi

  # 4. Try Python 3 with time module
  attempts[attempts_count]="Python"
  attempts_count=$((attempts_count + 1))
  if bashunit::dependencies::has_python; then
    _BASHUNIT_CLOCK_NOW_IMPL="python"
    return 0
  fi

  # 5. Try Node.js
  attempts[attempts_count]="Node"
  attempts_count=$((attempts_count + 1))
  if bashunit::dependencies::has_node; then
    _BASHUNIT_CLOCK_NOW_IMPL="node"
    return 0
  fi

  # 6. Windows fallback with PowerShell
  attempts[attempts_count]="PowerShell"
  attempts_count=$((attempts_count + 1))
  if bashunit::check_os::is_windows && bashunit::dependencies::has_powershell; then
    _BASHUNIT_CLOCK_NOW_IMPL="powershell"
    return 0
  fi

  # 7. Very last fallback: seconds resolution only
  attempts[attempts_count]="date-seconds"
  attempts_count=$((attempts_count + 1))
  if date +%s &>/dev/null; then
    _BASHUNIT_CLOCK_NOW_IMPL="date-seconds"
    return 0
  fi

  # 8. All methods failed
  printf "bashunit::clock::now implementations tried: %s\n" "${attempts[*]}" >&2
  echo ""
  return 1
}

# Returns 0 when the chosen clock impl forks an interpreter (perl/python/node/
# powershell), so callers can skip optional timing to avoid a per-read fork (#765).
function bashunit::clock::is_expensive() {
  [ -n "$_BASHUNIT_CLOCK_NOW_IMPL" ] || bashunit::clock::_choose_impl >/dev/null 2>&1 || true
  case "$_BASHUNIT_CLOCK_NOW_IMPL" in
  perl | python | node | powershell) return 0 ;;
  *) return 1 ;;
  esac
}

_BASHUNIT_CLOCK_NOW_OUT=""

# Return-slot variant of bashunit::clock::now: writes the current time in
# nanoseconds into _BASHUNIT_CLOCK_NOW_OUT. The `shell` branch reads
# EPOCHREALTIME directly (folding in shell_time) so the per-test hot path pays
# no command-substitution fork on Bash 5.0+; `date-seconds` forks once instead
# of twice. Interpreter/`date` branches keep a single internal fork.
# Returns: 0 on success, 1 when no clock implementation is available.
function bashunit::clock::now_to_slot() {
  if [ -z "$_BASHUNIT_CLOCK_NOW_IMPL" ]; then
    _BASHUNIT_CLOCK_NOW_OUT=""
    bashunit::clock::_choose_impl || return 1
    # _choose_impl may have already read the current time while selecting an
    # interpreter impl (e.g. perl); reuse that value for this first read instead
    # of forking a second interpreter.
    if [ -n "$_BASHUNIT_CLOCK_NOW_OUT" ]; then
      return 0
    fi
  fi

  case "$_BASHUNIT_CLOCK_NOW_IMPL" in
  perl)
    _BASHUNIT_CLOCK_NOW_OUT="$(perl -MTime::HiRes -e 'printf("%.0f\n", Time::HiRes::time() * 1000000000)')"
    ;;
  python)
    _BASHUNIT_CLOCK_NOW_OUT="$(
      python - <<'EOF'
import time, sys
sys.stdout.write(str(int(time.time() * 1000000000)))
EOF
    )"
    ;;
  node)
    _BASHUNIT_CLOCK_NOW_OUT="$(node -e 'process.stdout.write((BigInt(Date.now()) * 1000000n).toString())')"
    ;;
  powershell)
    _BASHUNIT_CLOCK_NOW_OUT="$(powershell -Command "\
        \$unixEpoch = [DateTime]'1970-01-01 00:00:00';\
        \$now = [DateTime]::UtcNow;\
        \$ticksSinceEpoch = (\$now - \$unixEpoch).Ticks;\
        \$nanosecondsSinceEpoch = \$ticksSinceEpoch * 100;\
        Write-Output \$nanosecondsSinceEpoch\
      ")"
    ;;
  date)
    _BASHUNIT_CLOCK_NOW_OUT="$(date +%s%N)"
    ;;
  date-seconds)
    local seconds
    seconds=$(date +%s)
    _BASHUNIT_CLOCK_NOW_OUT="$((seconds * 1000000000))"
    ;;
  shell)
    # Read EPOCHREALTIME directly (no shell_time subshell) on the hot path;
    # both '.' and ',' decimal separators are handled for locale portability.
    local shell_time="${EPOCHREALTIME:-}"
    local seconds="${shell_time%%[.,]*}"
    local microseconds="${shell_time#*[.,]}"
    if [ "$seconds" = "$shell_time" ]; then
      microseconds=""
    fi
    # Pad to 6 digits and strip leading zeros for arithmetic
    microseconds="${microseconds}000000"
    microseconds="${microseconds:0:6}"
    microseconds="${microseconds#"${microseconds%%[!0]*}"}"
    microseconds="${microseconds:-0}"
    _BASHUNIT_CLOCK_NOW_OUT="$(((seconds * 1000000000) + (microseconds * 1000)))"
    ;;
  *)
    bashunit::clock::_choose_impl || return 1
    bashunit::clock::now_to_slot
    ;;
  esac
}

function bashunit::clock::now() {
  bashunit::clock::now_to_slot || return 1
  echo "$_BASHUNIT_CLOCK_NOW_OUT"
}

function bashunit::clock::shell_time() {
  # Get time directly from the shell variable EPOCHREALTIME (Bash 5+)
  [ -n "${EPOCHREALTIME+x}" ] && [ -n "$EPOCHREALTIME" ] && LC_ALL=C echo "$EPOCHREALTIME"
}

function bashunit::clock::total_runtime_in_milliseconds() {
  local end_time
  end_time=$(bashunit::clock::now)
  if [ -n "$end_time" ]; then
    bashunit::math::calculate "($end_time - $_BASHUNIT_START_TIME) / 1000000"
  else
    echo ""
  fi
}

function bashunit::clock::init() {
  _BASHUNIT_START_TIME=$(bashunit::clock::now)
}
