---
description: "Measure bash script execution time with bashunit benchmarks to find performance bottlenecks and enforce performance requirements in your test suite."
---

# Benchmarks

Benchmarks measure the execution time of your scripts with dedicated functions, helping you identify performance bottlenecks and ensure your code meets performance requirements.

## Quick Start

Create a benchmark file with functions prefixed with `bench`:

::: code-group
```bash [tests/benchmark/example_bench.sh]
#!/usr/bin/env bash

# @revs=100 @its=5
function bench_my_function() {
  my_function_under_test
}
```
```bash [Running]
./bashunit bench tests/benchmark/
```
:::

## Annotations

Control benchmark behavior with comment annotations placed before the function:

| Annotation | Description | Default |
|------------|-------------|---------|
| `@revs=N` | Number of revolutions (function calls per iteration) | 1 |
| `@its=N` | Number of iterations (separate processes) | 1 |
| `@max_ms=N` | Maximum allowed average time in milliseconds (decimals allowed, e.g. `1.5`) | - |

::: code-group
```bash [Basic benchmark]
# @revs=1000 @its=5
function bench_string_operations() {
  local result="${text//foo/bar}"
}
```
```bash [With threshold]
# @revs=10 @its=3 @max_ms=50
function bench_api_call() {
  curl -s "$API_URL/health" > /dev/null
}
```
:::

::: tip
Each iteration runs in a separate process, providing isolated timing measurements. Higher `@its` values give more reliable averages.
:::

## Running Benchmarks

Run benchmarks using the `bench` command:

::: code-group
```bash [Run all benchmarks]
./bashunit bench tests/benchmark/
```
```bash [Run specific file]
./bashunit bench tests/benchmark/string_bench.sh
```
```bash [With simple output]
./bashunit bench --simple tests/benchmark/
```
:::

If no file is provided, bashunit uses [`BASHUNIT_DEFAULT_PATH`](/configuration) to locate all `*bench.sh` files.

## Output Formats

### Simple Output

Shows progress dots during execution, followed by a summary table:

::: code-group
```bash [Command]
./bashunit bench --simple
```
```[Output]
.........

Benchmark Results (avg ms)
======================================================================

Name                                 Revs    Its    Avg(ms)     Status
bench_string_operations               100      5         12
bench_api_call                         10      3         45       ≤ 50
bench_slow_function                    50      2        150      > 100
```
:::

### Detailed Output

Shows timing for each iteration as it runs:

::: code-group
```bash [Command]
./bashunit bench
```
```[Output]
Running tests/benchmark/example_bench.sh
Bench string operations [1/5] 13 ms
Bench string operations [2/5] 11 ms
Bench string operations [3/5] 12 ms
Bench string operations [4/5] 12 ms
Bench string operations [5/5] 11 ms
Bench api call [1/3] 43 ms
Bench api call [2/3] 47 ms
Bench api call [3/3] 45 ms


Benchmark Results (avg ms)
=====================================================================

Name                                 Revs    Its    Avg(ms)    Status
bench_string_operations               100      5         12
bench_api_call                         10      3         45      ≤ 50
```
:::

### Machine-readable reports

The console table is for a human reading a terminal. For CI, write the run to a
file that can be stored as an artifact, charted over time, or compared by a
later run:

::: code-group
```bash [JSON]
./bashunit bench --report-json bench.json
```
```bash [JUnit]
./bashunit bench --report-junit bench.xml
```
```json [bench.json]
{
  "run": {
    "timestamp": "2026-08-12T21:52:36",
    "duration_ms": 209,
    "bashunit_version": "0.46.0",
    "bash_version": "5.2.21",
    "os": "Linux"
  },
  "benchmarks": [
    {
      "file": "tests/benchmark/example_bench.sh",
      "function": "bench_api_call",
      "name": "Bench api call",
      "revs": 10,
      "its": 3,
      "iterations_ms": [43, 47, 45],
      "average_ms": 45,
      "min_ms": 43.000,
      "max_ms": 47.000,
      "median_ms": 45.000,
      "threshold_ms": 50,
      "within_threshold": true
    }
  ]
}
```
:::

`threshold_ms` and `within_threshold` are `null` for a benchmark with no
[`@max_ms`](#setting-thresholds) — an absent threshold is not a threshold of
zero, and a chart has to be able to tell those apart.

The JUnit file reports one `<testcase>` per benchmark, with a `<failure
type="PerformanceRegression">` for each one over its `@max_ms`, so a CI test
reporter shows benchmarks next to tests.

## Status Column

The status column indicates threshold results:

| Status | Meaning |
|--------|---------|
| (empty) | No threshold set |
| `≤ N` | Average time is at or below `@max_ms` threshold (pass) |
| `> N` | Average time exceeds `@max_ms` threshold (fail) |

## Setting Thresholds

Use `@max_ms` to fail benchmarks that exceed a time limit:

::: code-group
```bash [Example]
# @revs=10 @its=3 @max_ms=100
function bench_critical_path() {
  process_request "$test_data"
}
```
:::

::: warning
Thresholds are checked against the average time across all iterations. A single slow iteration won't cause failure if the average remains acceptable.
:::

## Best Practices

### Isolate the Code Under Test

Minimize setup code inside the benchmark function:

::: code-group
```bash [Good]
function set_up() {
  TEST_DATA=$(generate_large_dataset)
}

# @revs=100 @its=5
function bench_process_data() {
  process "$TEST_DATA"
}
```
```bash [Avoid]
# @revs=100 @its=5
function bench_process_data() {
  local data=$(generate_large_dataset)  # Measured!
  process "$data"
}
```
:::

### Choose Appropriate Revolutions

- **I/O operations** (network, disk): Lower `@revs` (1-10)
- **CPU operations** (string processing, math): Higher `@revs` (100-1000)

### Run Multiple Iterations

Use `@its` >= 3 for more reliable averages, especially for operations with variable timing.

## Related

- [Command-Line](/command-line) — full reference for CLI flags and options
- [Configuration](/configuration) — environment variables such as `BASHUNIT_DEFAULT_PATH`
- [Coverage](/coverage) — measure which code paths your tests exercise

<script setup>
import pkg from '../package.json'
</script>
