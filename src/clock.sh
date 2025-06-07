#!/usr/bin/env bash

function clock::now() {
  local shell_time

  # 1. Try using native shell EPOCHREALTIME (if available)
  if shell_time="$(clock::shell_time)"; then
    local seconds="${shell_time%%.*}"
    local microseconds="${shell_time#*.}"
    math::calculate "($seconds * 1000000000) + ($microseconds * 1000)"
    return 0
  fi

  # 2. Try Perl with Time::HiRes
  if dependencies::has_perl && perl -MTime::HiRes -e "" &>/dev/null; then
    perl -MTime::HiRes -e 'printf("%.0f\n", Time::HiRes::time() * 1000000000)' && return 0
  fi

  # 3. Windows fallback with PowerShell
  if check_os::is_windows && dependencies::has_powershell; then
    powershell -Command "
      \$unixEpoch = [DateTime]'1970-01-01 00:00:00';
      \$now = [DateTime]::UtcNow;
      \$ticksSinceEpoch = (\$now - \$unixEpoch).Ticks;
      \$nanosecondsSinceEpoch = \$ticksSinceEpoch * 100;
      Write-Output \$nanosecondsSinceEpoch
    " && return 0
  fi

  # 4. Unix fallback using `date +%s%N` (if not macOS or Alpine)
  if ! check_os::is_macos && ! check_os::is_alpine; then
    local result
    result=$(date +%s%N 2>/dev/null)
    if [[ "$result" != *N && "$result" =~ ^[0-9]+$ ]]; then
      echo "$result"
      return 0
    fi
  fi

  # 5. All methods failed
  echo ""
  return 1
}

function clock::shell_time() {
  # Get time directly from the shell variable EPOCHREALTIME (Bash 5+)
  [[ -n ${EPOCHREALTIME+x} && -n "$EPOCHREALTIME" ]] && LC_ALL=C echo "$EPOCHREALTIME"
}

function clock::total_runtime_in_milliseconds() {
  local end_time
  end_time=$(clock::now)
  if [[ -n $end_time ]]; then
    math::calculate "($end_time - $_START_TIME) / 1000000"
  else
    echo ""
  fi
}

function clock::total_runtime_in_nanoseconds() {
  local end_time
  end_time=$(clock::now)
  if [[ -n $end_time ]]; then
    math::calculate "$end_time - $_START_TIME"
  else
    echo ""
  fi
}

function clock::init() {
  _START_TIME=$(clock::now)
}
