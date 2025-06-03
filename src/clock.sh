#!/usr/bin/env bash

function clock::now() {
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

  local shell_time has_shell_time
  shell_time="$(clock::shell_time)"
  has_shell_time="$?"
  if [[ "$has_shell_time" -eq 0 ]]; then
    local seconds microseconds
    seconds="${shell_time%%.*}"
    microseconds="${shell_time#*.}"
    microseconds="${microseconds:-0}"

    echo $((seconds * 1000000000 + microseconds * 1000))
    return 0
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
    echo $(((end_time - _START_TIME)/1000000))
  else
    echo ""
  fi
}

function clock::total_runtime_in_nanoseconds() {
  end_time=$(clock::now)
  if [[ -n $end_time ]]; then
    echo $((end_time - _START_TIME))
  else
    echo ""
  fi
}

function clock::init() {
  _START_TIME=$(clock::now)
}
