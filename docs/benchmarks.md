# Benchmarks

bashunit allows defining benchmark functions to measure execution time of your scripts.

Functions prefixed with `bench` are treated as benchmarks. You can annotate them with
`@revs` (revolutions) and `@its` (iterations) comments to control how many times the code
is executed. Use `@max_ms` to mark the benchmark as failed when the average
execution time exceeds the given value in milliseconds.

Each iteration is executed in a separate process, and the average time is reported.

```bash
# @revs=1000 @its=5
function bench_my_function() {
  my_function_under_test
}
```

You can optionally fail a benchmark when it exceeds a max_ms:

```bash
# @revs=10 @its=1 @max_ms=5
function bench_slow() {
  slow_operation
}
```

Run benchmarks using the `--bench` option. Each iteration prints its duration
when using detailed output, or a dot when simple output is enabled:

```bash
./bashunit --bench tests/benchmarks.sh
```

If no file is provided, **bashunit** uses `BASHUNIT_DEFAULT_PATH` to locate all `*bench.sh` files.

Example output:

::: code-group
```bash [Simple]
./bashunit --bench --simple

.........

Benchmark Results (avg ms)
======================================================================

Name                                 Revs    Its    Avg(ms)     Status
bench_bashunit_runs_benchmarks          3      2        727
bench_bashunit_functional_run           1      1        243
bench_bashunit_default_path             1      1        731      > 600
bench_run_bashunit_functional           2      1        371      > 300
bench_sleep                             5      2         21       ≤ 25
bench_sleep_synonym                     3      2         32
```
```bash [Detailed]
./bashunit --bench

Running tests/benchmark/bashunit_bench.sh
Bench bashunit runs benchmarks [1/2] 843 ms
Bench bashunit runs benchmarks [2/2] 834 ms
Bench bashunit functional run [1/1] 281 ms
Bench bashunit default path [1/1] 736 ms

Running tests/benchmark/fixtures/bashunit_functional_bench.sh
Bench run bashunit functional [1/1] 430 ms

Running tests/benchmark/fixtures/bashunit_sleep_bench.sh
Bench sleep [1/2] 48 ms
Bench sleep [2/2] 26 ms
Bench sleep synonym [1/2] 32 ms
Bench sleep synonym [2/2] 34 ms


Benchmark Results (avg ms)
=====================================================================

Name                                 Revs    Its    Avg(ms)    Status
bench_bashunit_runs_benchmarks          3      2        838
bench_bashunit_functional_run           1      1        281
bench_bashunit_default_path             1      1        736     > 600
bench_run_bashunit_functional           2      1        430     > 300
bench_sleep                             5      2         37      > 25
bench_sleep_synonym                     3      2         33

```
:::



<script setup>
import pkg from '../package.json'
</script>
