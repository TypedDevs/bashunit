#!/usr/bin/env bash

# Comparing a bench run against a previous one.
#
# `@max_ms` is an absolute ceiling. To survive the slowest CI runner it has to
# be loose, which means it only catches catastrophes and says nothing about the
# 30% slowdown that stays under it. A baseline compares this run against the
# last one instead, which is the question every performance campaign in this
# repo (#761, #798, #830, #977) actually asked.
#
# The comparison uses the **median**, not the average: one descheduled
# iteration on a shared runner moves the mean far more than the middle value,
# and a gate that cries wolf gets disabled.
#
# The baseline file is the --report-json document of an earlier run. It is
# parsed with awk rather than jq: jq is optional everywhere else in bashunit,
# and a gate that silently does nothing when a tool is missing is the bug this
# feature exists to prevent.

_BASHUNIT_BASELINE_NAMES=()
_BASHUNIT_BASELINE_MEDIANS=()

##
# Reads the benchmarks of a --report-json file into the arrays above.
# Aborts the run when the file is missing or holds no benchmark entry: a
# baseline that quietly compares against nothing would report every run green.
# Arguments: $1 - baseline file
##
function bashunit::benchmark::baseline_load() {
  local file=$1
  _BASHUNIT_BASELINE_NAMES=()
  _BASHUNIT_BASELINE_MEDIANS=()

  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    printf "%sError: cannot read the baseline file: '%s'.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "$file" "${_BASHUNIT_COLOR_DEFAULT}" >&2
    exit 1
  fi

  local name median
  while IFS=$'\t' read -r name median; do
    [ -n "$name" ] || continue
    _BASHUNIT_BASELINE_NAMES[${#_BASHUNIT_BASELINE_NAMES[@]}]="$name"
    _BASHUNIT_BASELINE_MEDIANS[${#_BASHUNIT_BASELINE_MEDIANS[@]}]="$median"
  done < <(env LC_ALL=C awk '
    # The document is bashunit s own, one field per line, so the pairing is a
    # matter of remembering the last "function" seen before each "median_ms".
    /"function"[[:space:]]*:/ {
      line = $0
      sub(/.*"function"[[:space:]]*:[[:space:]]*"/, "", line)
      sub(/".*/, "", line)
      fn = line
    }
    /"median_ms"[[:space:]]*:/ {
      line = $0
      sub(/.*"median_ms"[[:space:]]*:[[:space:]]*/, "", line)
      sub(/[^0-9.eE+-].*/, "", line)
      if (fn != "" && line != "") { printf "%s\t%s\n", fn, line; fn = "" }
    }
  ' "$file")

  if [ "${#_BASHUNIT_BASELINE_NAMES[@]}" -eq 0 ]; then
    printf "%sError: the baseline file holds no benchmark results: '%s'.%s\n" \
      "${_BASHUNIT_COLOR_FAILED}" "$file" "${_BASHUNIT_COLOR_DEFAULT}" >&2
    exit 1
  fi
}

##
# The recorded median for a benchmark, or empty when the baseline does not
# know it. Writes into _BASHUNIT_BASELINE_MEDIAN_OUT.
##
_BASHUNIT_BASELINE_MEDIAN_OUT=""
function bashunit::benchmark::baseline_median_of() {
  local wanted=$1
  local i=0
  local total=${#_BASHUNIT_BASELINE_NAMES[@]}
  _BASHUNIT_BASELINE_MEDIAN_OUT=""

  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_BASELINE_NAMES[i]}" = "$wanted" ]; then
      _BASHUNIT_BASELINE_MEDIAN_OUT="${_BASHUNIT_BASELINE_MEDIANS[i]}"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

##
# The percentage change from $1 to $2, formatted with a sign, and whether it
# exceeds $3 percent. Prints "<delta>\t<regressed>".
#
# awk under LC_ALL=C throughout: the numbers are decimals and several CI
# locales would render them with a comma (#912).
##
function bashunit::benchmark::baseline_delta() {
  local before=$1
  local now=$2
  local tolerance=$3

  env LC_ALL=C awk -v before="$before" -v now="$now" -v tol="$tolerance" '
    BEGIN {
      before = before + 0
      now = now + 0
      if (before <= 0) {
        # No usable previous number: report the change as unknown rather than
        # dividing by zero and calling it an infinite regression.
        printf "n/a\tno\n"
        exit
      }
      delta = ((now - before) / before) * 100
      printf "%+.1f%%\t%s\n", delta, (delta > tol + 0 ? "yes" : "no")
    }
  '
}

##
# Compares the run just finished against the loaded baseline, prints the table
# and returns 1 when any benchmark regressed beyond the tolerance.
# Arguments: $1 - tolerance percentage
##
function bashunit::benchmark::baseline_compare() {
  local tolerance=$1
  local regressed=0

  printf "\nBaseline comparison (median ms, tolerance %s%%)\n" "$tolerance"
  bashunit::print_line 80 "="
  printf '%-40s %12s %12s %10s\n' "Name" "Baseline" "Current" "Delta"

  local i total name median before delta verdict
  total=${#_BASHUNIT_BENCH_NAMES[@]}
  i=0
  while [ "$i" -lt "$total" ]; do
    name="${_BASHUNIT_BENCH_NAMES[$i]:-}"
    bashunit::benchmark::stats_to_slots "${_BASHUNIT_BENCH_DURATIONS[$i]:-}"
    median=$_BASHUNIT_BENCH_STATS_MEDIAN_OUT

    if ! bashunit::benchmark::baseline_median_of "$name"; then
      printf '%-40s %12s %12s %10s\n' "$name" "-" "$median" "new"
      i=$((i + 1))
      continue
    fi
    before=$_BASHUNIT_BASELINE_MEDIAN_OUT

    IFS=$'\t' read -r delta verdict < <(
      bashunit::benchmark::baseline_delta "$before" "$median" "$tolerance"
    )

    if [ "$verdict" = "yes" ]; then
      regressed=$((regressed + 1))
      printf '%-40s %12s %12s %s%10s%s\n' "$name" "$before" "$median" \
        "$_BASHUNIT_COLOR_FAILED" "$delta" "$_BASHUNIT_COLOR_DEFAULT"
    else
      printf '%-40s %12s %12s %10s\n' "$name" "$before" "$median" "$delta"
    fi
    i=$((i + 1))
  done

  # Reported, never fatal: a benchmark that was deleted on purpose must not
  # fail the build of the commit that deleted it.
  local j baseline_total baseline_name found k
  baseline_total=${#_BASHUNIT_BASELINE_NAMES[@]}
  j=0
  while [ "$j" -lt "$baseline_total" ]; do
    baseline_name="${_BASHUNIT_BASELINE_NAMES[$j]}"
    found=false
    k=0
    while [ "$k" -lt "$total" ]; do
      if [ "${_BASHUNIT_BENCH_NAMES[$k]:-}" = "$baseline_name" ]; then
        found=true
        break
      fi
      k=$((k + 1))
    done
    if [ "$found" = false ]; then
      printf '%-40s %12s %12s %10s\n' "$baseline_name" \
        "${_BASHUNIT_BASELINE_MEDIANS[$j]}" "-" "removed"
    fi
    j=$((j + 1))
  done

  if [ "$regressed" -gt 0 ]; then
    printf "\n%s%s%s\n" "$_BASHUNIT_COLOR_FAILED" \
      " Performance regression in $regressed benchmark(s) " "$_BASHUNIT_COLOR_DEFAULT"
    return 1
  fi

  return 0
}
