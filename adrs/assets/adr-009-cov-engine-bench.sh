#!/usr/bin/env bash
# Spike #854: compare per-line coverage-capture cost.
#   baseline (none) vs DEBUG-trap-calls-a-function vs set -x to a file.
# Prints wall overhead each mechanism adds to an identical workload.
ITER=${1:-20000}
TMP=$(mktemp -d)

now() { perl -MTime::HiRes -e 'printf "%.6f\n", Time::HiRes::time()'; }
delta() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.3f", b-a}'; }

workload() {
  local i=0 x y
  while [ "$i" -lt "$ITER" ]; do
    x=$((i * 2))
    y=$((x + 1))
    i=$((y - x + i)) # y-x == 1, so this advances i by one; keeps x and y used
  done
}

# --- Baseline: no instrumentation ---
t0=$(now); workload; t1=$(now)
base=$(delta "$t0" "$t1")

# --- DEBUG trap mimicking record_line (in-memory buffer, flush at 100) ---
_BUF=""; _CNT=0
record() {
  _BUF="${_BUF}$1
"
  _CNT=$((_CNT + 1))
  if [ "$_CNT" -ge 100 ]; then printf '%s' "$_BUF" >>"$TMP/trap.data"; _BUF=""; _CNT=0; fi
}
: >"$TMP/trap.data"
set -o functrace
t0=$(now)
trap 'record "$LINENO"' DEBUG
workload
trap - DEBUG
t1=$(now)
set +o functrace
printf '%s' "$_BUF" >>"$TMP/trap.data"
trap_t=$(delta "$t0" "$t1")
trap_events=$(grep -c . "$TMP/trap.data")

# --- xtrace to a file (PS4 carries the line number, as real coverage would) ---
t0=$(now)
{ PS4='+$LINENO '
  set -x
  workload
  set +x
} 2>"$TMP/xtrace.raw"
t1=$(now)
xtrace_run=$(delta "$t0" "$t1")
t2=$(now)
xtrace_events=$(grep -c '^+' "$TMP/xtrace.raw")
t3=$(now)
xtrace_parse=$(delta "$t2" "$t3")
xtrace_total=$(awk -v a="$xtrace_run" -v b="$xtrace_parse" 'BEGIN{printf "%.3f", a+b}')

trap_over=$(delta "$base" "$trap_t")
xtrace_over=$(delta "$base" "$xtrace_run")
raw_size=$(wc -c <"$TMP/xtrace.raw" | tr -d ' ')

echo "bash $BASH_VERSION | iterations=$ITER"
echo "  baseline      ${base}s"
echo "  DEBUG trap    ${trap_t}s  (+${trap_over}s, events=${trap_events})"
echo "  xtrace run    ${xtrace_run}s (+${xtrace_over}s) parse ${xtrace_parse}s events=${xtrace_events}"
echo "  xtrace total  ${xtrace_total}s"
echo "  raw trace     ${raw_size} bytes"
rm -rf "$TMP"
