#!/usr/bin/env bash

# Returns 0 when this Bash supports `wait -n` (Bash 4.3+), 1 otherwise.
function bashunit::runner::_supports_wait_n() {
  local major="${BASH_VERSINFO[0]:-0}"
  local minor="${BASH_VERSINFO[1]:-0}"
  if [ "$major" -gt 4 ]; then
    return 0
  fi
  if [ "$major" -eq 4 ] && [ "$minor" -ge 3 ]; then
    return 0
  fi
  return 1
}

_BASHUNIT_RUNNER_RUNNING_JOBS_OUT=0

# Counts running background jobs into _BASHUNIT_RUNNER_RUNNING_JOBS_OUT. `jobs -pr`
# still needs one command substitution, but the line count is pure-bash, so this
# drops the extra `wc` fork per poll iteration on the parallel hot path (#761).
function bashunit::runner::_count_running_jobs() {
  local running
  running=$(jobs -pr)
  if [ -z "$running" ]; then
    _BASHUNIT_RUNNER_RUNNING_JOBS_OUT=0
    return
  fi
  local newlines="${running//[!$'\n']/}"
  _BASHUNIT_RUNNER_RUNNING_JOBS_OUT=$((${#newlines} + 1))
}

function bashunit::runner::wait_for_job_slot() {
  local max_jobs="${BASHUNIT_PARALLEL_JOBS:-0}"
  if [ "$max_jobs" -le 0 ]; then
    return 0
  fi

  if bashunit::runner::_supports_wait_n; then
    # Bash 4.3+: block until any child exits. No polling, no sleep latency.
    bashunit::runner::_count_running_jobs
    while [ "$_BASHUNIT_RUNNER_RUNNING_JOBS_OUT" -ge "$max_jobs" ]; do
      wait -n 2>/dev/null || break
      bashunit::runner::_count_running_jobs
    done
    return 0
  fi

  # Bash 3.x fallback: adaptive poll starting at 50ms, growing to 200ms to
  # reduce `jobs -r` overhead on long-running tests while staying responsive.
  local delay="0.05"
  local iterations=0
  while true; do
    bashunit::runner::_count_running_jobs
    if [ "$_BASHUNIT_RUNNER_RUNNING_JOBS_OUT" -lt "$max_jobs" ]; then
      break
    fi
    sleep "$delay"
    iterations=$((iterations + 1))
    if [ "$iterations" -eq 4 ]; then
      delay="0.1"
    elif [ "$iterations" -eq 20 ]; then
      delay="0.2"
    fi
  done
}

function bashunit::runner::spinner() {
  # Only show spinner when output is to a terminal
  if [ ! -t 1 ]; then
    # Not a terminal, just wait silently
    while true; do sleep 1; done
    return
  fi

  # Don't show spinner in no-progress mode, nor when stdout carries a machine
  # format the frames would corrupt.
  if bashunit::env::is_no_progress_enabled || bashunit::env::is_machine_output_enabled; then
    while true; do sleep 1; done
    return
  fi

  if bashunit::env::is_simple_output_enabled; then
    printf "\n"
  fi

  local delay=0.1
  local spin_chars="|/-\\"
  while true; do
    local i
    for ((i = 0; i < ${#spin_chars}; i++)); do
      printf "\r%s" "${spin_chars:$i:1}"
      sleep "$delay"
    done
  done
}
