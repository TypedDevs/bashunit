#!/usr/bin/env bash

# The output primitive every result line goes through, and its TAP variant.

_BASHUNIT_TOTAL_TESTS_COUNT=0

##
# Emit one progress entry for a finished test, in whichever output mode is
# active (verbose line, --simple char, or TAP).
#
# Lived in state.sh until #868. Rendering from the counter module was a layering
# inversion, and it was the sole reason for the state -> parallel call cycle that
# #862 broke; keep it here so state.sh owns counters and the payload only.
# Arguments: $1 - test type, $2 - already formatted line
##
function bashunit::console_results::print_line() {
  local type=$1
  local line=$2

  ((_BASHUNIT_TOTAL_TESTS_COUNT++)) || true

  bashunit::state::add_test_output "[$type]$line"

  if bashunit::env::is_no_progress_enabled; then
    return
  fi

  if bashunit::env::is_tap_output_enabled; then
    bashunit::console_results::print_tap_line "$type" "$line"
    return
  fi

  if ! bashunit::env::is_simple_output_enabled; then
    printf "%s\n" "$line"
    return
  fi

  local char
  case "$type" in
  successful) char="." ;;
  failure) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  failed) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  failed_snapshot) char="${_BASHUNIT_COLOR_FAILED}F${_BASHUNIT_COLOR_DEFAULT}" ;;
  skipped) char="${_BASHUNIT_COLOR_SKIPPED}S${_BASHUNIT_COLOR_DEFAULT}" ;;
  incomplete) char="${_BASHUNIT_COLOR_INCOMPLETE}I${_BASHUNIT_COLOR_DEFAULT}" ;;
  snapshot) char="${_BASHUNIT_COLOR_SNAPSHOT}N${_BASHUNIT_COLOR_DEFAULT}" ;;
  risky) char="${_BASHUNIT_COLOR_RISKY}R${_BASHUNIT_COLOR_DEFAULT}" ;;
  error) char="${_BASHUNIT_COLOR_FAILED}E${_BASHUNIT_COLOR_DEFAULT}" ;;
  *) char="?" && bashunit::log "warning" "unknown test type '$type'" ;;
  esac

  if bashunit::parallel::is_enabled; then
    printf "%s" "$char"
  else
    if ((_BASHUNIT_TOTAL_TESTS_COUNT % 50 == 0)); then
      printf "%s\n" "$char"
    else
      printf "%s" "$char"
    fi
  fi
}


function bashunit::console_results::print_tap_line() {
  local type=$1
  local line=$2

  local clean_line
  clean_line=$(printf "%s" "$line" | sed 's/\x1B\[[0-9;]*[mK]//g')
  local test_name="${clean_line#*: }"
  test_name="${test_name%%$'\n'*}"
  # Strip trailing whitespace and duration
  test_name=$(printf "%s" "$test_name" | \
    sed 's/[[:space:]]*[0-9][0-9]*m\{0,1\}[[:space:]]*[0-9.]*[ms]*[[:space:]]*$//')

  case "$type" in
  successful)
    printf "ok %d - %s\n" "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  failure | failed | failed_snapshot | error)
    printf "not ok %d - %s\n" "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    local detail_line
    printf "  ---\n"
    while IFS= read -r detail_line; do
      detail_line=$(printf "%s" "$detail_line" | sed 's/\x1B\[[0-9;]*[mK]//g')
      if [ -n "$detail_line" ] \
        && [ "$(echo "$detail_line" | "$GREP" -cF "Failed:" || true)" -eq 0 ] \
        && [ "$(echo "$detail_line" | "$GREP" -cF "Error:" || true)" -eq 0 ]; then
        local trimmed="${detail_line#"${detail_line%%[![:space:]]*}"}"
        printf "  %s\n" "$trimmed"
      fi
    done <<< "$clean_line"
    printf "  ...\n"
    ;;
  skipped)
    local skip_name="${test_name%%   *}"
    local skip_reason="${test_name#"$skip_name"}"
    skip_reason="${skip_reason#"${skip_reason%%[![:space:]]*}"}"
    if [ -n "$skip_reason" ]; then
      printf "ok %d - %s # SKIP %s\n" \
        "$_BASHUNIT_TOTAL_TESTS_COUNT" "$skip_name" "$skip_reason"
    else
      printf "ok %d - %s # SKIP\n" \
        "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    fi
    ;;
  incomplete)
    printf "ok %d - %s # TODO incomplete\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  snapshot)
    printf "ok %d - %s # snapshot\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  risky)
    printf "ok %d - %s # RISKY no assertions\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  *)
    printf "not ok %d - %s\n" \
      "$_BASHUNIT_TOTAL_TESTS_COUNT" "$test_name"
    ;;
  esac
}
