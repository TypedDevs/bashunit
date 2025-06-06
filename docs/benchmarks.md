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

```-vue
bashunit - {{ pkg.version }}

Benchmark Results (avg ms)
Name                                         Revs      Its  Avg(ms)
bench_my_function                             1000        5    12.34
```

<script setup>
import pkg from '../package.json'
</script>
