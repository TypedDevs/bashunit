#!/usr/bin/env bash

_CLOCK_NOW_IMPL=""

function clock::_choose_impl() {
  local shell_time
  local attempts=()

  # 1. Try Perl with Time::HiRes
  attempts[${#attempts[@]}]="Perl"
  if dependencies::has_perl && perl -MTime::HiRes -e "" &>/dev/null; then
    _CLOCK_NOW_IMPL="perl"
    return 0
  fi

  # 2. Try Python 3 with time module
  attempts[${#attempts[@]}]="Python"
  if dependencies::has_python; then
    _CLOCK_NOW_IMPL="python"
    return 0
  fi

  # 3. Try Node.js
  attempts[${#attempts[@]}]="Node"
  if dependencies::has_node; then
    _CLOCK_NOW_IMPL="node"
    return 0
  fi
  # 4. Windows fallback with PowerShell
  attempts[${#attempts[@]}]="PowerShell"
  if check_os::is_windows && dependencies::has_powershell; then
    _CLOCK_NOW_IMPL="powershell"
    return 0
  fi

  # 5. Unix fallback using `date +%s%N` (if not macOS or Alpine)
  attempts[${#attempts[@]}]="date"
  if ! check_os::is_macos && ! check_os::is_alpine; then
    local result
    result=$(date +%s%N 2>/dev/null)
    if [[ "$result" != *N && "$result" =~ ^[0-9]+$ ]]; then
      _CLOCK_NOW_IMPL="date"
      return 0
    fi
  fi

  # 6. Try using native shell EPOCHREALTIME (if available)
  attempts[${#attempts[@]}]="EPOCHREALTIME"
  if shell_time="$(clock::shell_time)"; then
    _CLOCK_NOW_IMPL="shell"
    return 0
  fi

  # 7. Very last fallback: seconds resolution only
  attempts[${#attempts[@]}]="date-seconds"
  if date +%s &>/dev/null; then
    _CLOCK_NOW_IMPL="date-seconds"
    return 0
  fi

  # 8. All methods failed
  printf "clock::now implementations tried: %s\n" "${attempts[*]}" >&2
  echo ""
  return 1
}

function clock::now() {
  if [[ -z "$_CLOCK_NOW_IMPL" ]]; then
    clock::_choose_impl || return 1
  fi

  case "$_CLOCK_NOW_IMPL" in
    perl)
      perl -MTime::HiRes -e 'printf("%.0f\n", Time::HiRes::time() * 1000000000)'
      ;;
    python)
      python - <<'EOF'
import time, sys
sys.stdout.write(str(int(time.time() * 1_000_000_000)))
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
      math::calculate "$seconds * 1000000000"
      ;;
    shell)
      # shellcheck disable=SC2155
      local shell_time="$(clock::shell_time)"
      local seconds="${shell_time%%.*}"
      local microseconds="${shell_time#*.}"
      math::calculate "($seconds * 1000000000) + ($microseconds * 1000)"
      ;;
    *)
      clock::_choose_impl || return 1
      clock::now
      ;;
  esac
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
