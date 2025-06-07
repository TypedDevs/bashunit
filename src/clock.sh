#!/usr/bin/env bash

function clock::now() {
  local shell_time
  if shell_time="$(clock::shell_time)"; then
    local seconds="${shell_time%%.*}"
    local microseconds="${shell_time#*.}"

    math::calculate "($seconds * 1000000000) + ($microseconds * 1000)"
    return 0
  fi

  if dependencies::has_perl && perl -MTime::HiRes -e "" > /dev/null 2>&1; then
    if perl -MTime::HiRes -e 'printf("%.0f\n",Time::HiRes::time()*1000000000)'; then
        return 0
    fi
  fi

  if check_os::is_windows && dependencies::has_powershell; then
      powershell -Command "
              \$unixEpoch = [DateTime]'1970-01-01 00:00:00';
              \$now = [DateTime]::UtcNow;
              \$ticksSinceEpoch = (\$now - \$unixEpoch).Ticks;
              \$nanosecondsSinceEpoch = \$ticksSinceEpoch * 100;
              Write-Output \$nanosecondsSinceEpoch
              "
      return 0
  fi

  if ! check_os::is_macos && ! check_os::is_alpine; then
    local result
    result=$(date +%s%N)
    if [[ "$result" != *N ]] && [[ "$result" -gt 0 ]]; then
      echo "$result"
      return 0
    fi
  fi

  echo ""
  return 1
}

function clock::shell_time() {
  # Get time directly from the shell rather than a program.
  [[ -n ${EPOCHREALTIME+x} && -n "$EPOCHREALTIME" ]] && LC_ALL=C echo "$EPOCHREALTIME"
}


function clock::total_runtime_in_milliseconds() {
  end_time=$(clock::now)
  if [[ -n $end_time ]]; then
    math::calculate "($end_time-$_START_TIME)/1000000"
  else
    echo ""
  fi
}

function clock::total_runtime_in_nanoseconds() {
  end_time=$(clock::now)
  if [[ -n $end_time ]]; then
    math::calculate "($end_time-$_START_TIME)"
  else
    echo ""
  fi
}

function clock::init() {
  _START_TIME=$(clock::now)
}
