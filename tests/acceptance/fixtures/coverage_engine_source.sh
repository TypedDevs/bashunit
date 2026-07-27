#!/usr/bin/env bash
# shellcheck disable=SC2034

# Measured source for the engine-equivalence oracle. Deliberately mixes the
# constructs where xtrace and the DEBUG trap are most likely to disagree:
# branches, loops, case arms, pipelines and line continuations.
#
# Results come back through a return slot rather than stdout: a `$(...)` capture
# would run the callee in a nested subshell, and the trap engine's line buffer
# dies with that subshell unless it happens to cross the flush threshold.

COVERAGE_ENGINE_FIXTURE_OUT=""

function coverage_engine_fixture::branch() {
  local value="$1"
  if [ "$value" -gt 10 ]; then
    COVERAGE_ENGINE_FIXTURE_OUT="big"
  else
    COVERAGE_ENGINE_FIXTURE_OUT="small"
  fi
}

function coverage_engine_fixture::loop() {
  local i
  local acc=""
  for i in 1 2 3; do
    acc="${acc}${i}"
  done
  while [ "${#acc}" -gt 1 ]; do
    acc="${acc%?}"
  done
  COVERAGE_ENGINE_FIXTURE_OUT="$acc"
}

function coverage_engine_fixture::pick() {
  case "$1" in
  a) COVERAGE_ENGINE_FIXTURE_OUT="A" ;;
  b) COVERAGE_ENGINE_FIXTURE_OUT="B" ;;
  *) COVERAGE_ENGINE_FIXTURE_OUT="other" ;;
  esac
}

function coverage_engine_fixture::piped() {
  local collected=""
  local piped
  while read -r piped; do
    collected="${collected}${piped}"
  done <<<"one"
  COVERAGE_ENGINE_FIXTURE_OUT="$collected"
}

function coverage_engine_fixture::continued() {
  COVERAGE_ENGINE_FIXTURE_OUT="a b \
c"
}

function coverage_engine_fixture::never_called() {
  COVERAGE_ENGINE_FIXTURE_OUT="unreachable"
}
