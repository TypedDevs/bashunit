#!/usr/bin/env bash

_BASHUNIT_CLOCK_NOW_IMPL=""

function bashunit::clock::_choose_impl() {
  local shell_time
  # Use explicit indices for Bash 3.0 compatibility (empty array access fails with set -u)
  local attempts_count=0
  local attempts

  # 1. Try Perl with Time::HiRes
  attempts[attempts_count]="Perl"
  attempts_count=$((attempts_count + 1))
  if bashunit::dependencies::has_perl && perl -MTime::HiRes -e "" &>/dev/null; then
    _BASHUNIT_CLOCK_NOW_IMPL="perl"
    return 0
  fi

  # 2. Try Python 3 with time module
  attempts[attempts_count]="Python"
  attempts_count=$((attempts_count + 1))
  if bashunit::dependencies::has_python; then
    _BASHUNIT_CLOCK_NOW_IMPL="python"
    return 0
  fi

  # 3. Try Node.js
  attempts[attempts_count]="Node"
  attempts_count=$((attempts_count + 1))
  if bashunit::dependencies::has_node; then
    _BASHUNIT_CLOCK_NOW_IMPL="node"
    return 0
  fi
  # 4. Windows fallback with PowerShell
  attempts[attempts_count]="PowerShell"
  attempts_count=$((attempts_count + 1))
  if bashunit::check_os::is_windows && bashunit::dependencies::has_powershell; then
    _BASHUNIT_CLOCK_NOW_IMPL="powershell"
    return 0
  fi

  # 5. Unix fallback using `date +%s%N` (if not macOS or Alpine)
  attempts[attempts_count]="date"
  attempts_count=$((attempts_count + 1))
  if ! bashunit::check_os::is_macos && ! bashunit::check_os::is_alpine; then
    local result
    result=$(date +%s%N 2>/dev/null)
    if [[ "$result" != *N ]] && bashunit::regex_match "$result" '^[0-9]+$'; then
      _BASHUNIT_CLOCK_NOW_IMPL="date"
      return 0
    fi
  fi

  # 6. Try using native shell EPOCHREALTIME (if available)
  attempts[attempts_count]="EPOCHREALTIME"
  attempts_count=$((attempts_count + 1))
  if shell_time="$(bashunit::clock::shell_time)"; then
    _BASHUNIT_CLOCK_NOW_IMPL="shell"
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

function bashunit::clock::now() {
  if [[ -z "$_BASHUNIT_CLOCK_NOW_IMPL" ]]; then
    bashunit::clock::_choose_impl || return 1
  fi

  case "$_BASHUNIT_CLOCK_NOW_IMPL" in
  perl)
    perl -MTime::HiRes -e 'printf("%.0f\n", Time::HiRes::time() * 1000000000)'
    ;;
  python)
    python - <<'EOF'
import time, sys
sys.stdout.write(str(int(time.time() * 1000000000)))
EOF
    ;;
  node)
    node -e 'process.stdout.write((BigInt(Date.now()) * 1000000n).toString())'
    ;;
  powershell)
    powershell -Command "\
        \$unixEpoch = [DateTime]'1970-01-01 00:00:00';\
        \$now = [DateTime]::UtcNow;\
        \$ticksSinceEpoch = (\$now - \$unixEpoch).Ticks;\
        \$nanosecondsSinceEpoch = \$ticksSinceEpoch * 100;\
        Write-Output \$nanosecondsSinceEpoch\
      "
    ;;
  date)
    date +%s%N
    ;;
  date-seconds)
    local seconds
    seconds=$(date +%s)
    bashunit::math::calculate "$seconds * 1000000000"
    ;;
  shell)
    # shellcheck disable=SC2155
    local shell_time="$(bashunit::clock::shell_time)"
    local seconds="${shell_time%%.*}"
    local microseconds="${shell_time#*.}"
    bashunit::math::calculate "($seconds * 1000000000) + ($microseconds * 1000)"
    ;;
  *)
    bashunit::clock::_choose_impl || return 1
    bashunit::clock::now
    ;;
  esac
}

function bashunit::clock::shell_time() {
  # Get time directly from the shell variable EPOCHREALTIME (Bash 5+)
  [[ -n ${EPOCHREALTIME+x} && -n "$EPOCHREALTIME" ]] && LC_ALL=C echo "$EPOCHREALTIME"
}

function bashunit::clock::total_runtime_in_milliseconds() {
  local end_time
  end_time=$(bashunit::clock::now)
  if [[ -n $end_time ]]; then
    bashunit::math::calculate "($end_time - $_BASHUNIT_START_TIME) / 1000000"
  else
    echo ""
  fi
}

function bashunit::clock::total_runtime_in_nanoseconds() {
  local end_time
  end_time=$(bashunit::clock::now)
  if [[ -n $end_time ]]; then
    bashunit::math::calculate "$end_time - $_BASHUNIT_START_TIME"
  else
    echo ""
  fi
}

function bashunit::clock::init() {
  _BASHUNIT_START_TIME=$(bashunit::clock::now)
}
