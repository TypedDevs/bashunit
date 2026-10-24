# Index provider and annotation metadata with shell variables

* Status: accepted
* Date: 2026-10-24

Related: https://github.com/TypedDevs/bashunit/issues/1392

## Context and Problem Statement

The provider scanner already reads a test file once. Its consumers still scan arrays of function names for every provider or annotation lookup. Resolving annotations in the runner and again inside each attempt repeats that work. A file with many annotated tests therefore spends increasing time finding metadata for later tests.

## Decision Outcome

Keep the arrays as the source of metadata values. Scan maps with up to 64 entries directly and build an index from function name to array position for larger maps. A 100-pair comparison found about 2 to 3ms of setup overhead for a 10-test annotated file when every map was indexed; avoiding that fixed cost keeps small files on their existing path. Use ordinary, unexported shell variables for index entries and Bash's indirect expansion to read them. This works on Bash 3.0 and newer, without an external command or a second implementation.

Index only the name domain emitted by the existing scanner: ASCII letters, digits, underscores and colons. A lookup outside that domain returns no entry. Escape underscores as `__` before escaping colons as `_c`, so different function names cannot produce the same variable name. Separate prefixes distinguish provider and annotation entries.

Record the first position for each name, preserving the previous scan's first-match behavior. Clear entries using the previous map's names before resetting its arrays. Build the index once after scanner output is loaded when the map exceeds the size limit. Small files, including the validated header-cache path, keep direct lookup. Recording another annotation invalidates its index flag so direct helper calls continue to see appended entries. The index has the same lifetime as its map and is inherited by test workers.

Use builtin `read` to assign an index variable by name. Its input is a small integer position. No index entry is exported and no generated shell text is evaluated. Missing entries use the existing empty/default return slots. If index construction fails, leave its flag off and use the arrays directly; the next reset removes any partial index entries.

## Alternatives

* Continue scanning all arrays: simplest storage, but large maps repeatedly walk earlier entries. Keep this path only for small maps.
* Cache only the last lookup: helps repeated data sets and attempts, but distinct tests still scan the map.
* Use associative arrays on Bash 4+: introduces a second implementation when native shell-variable lookup already handles the scanner's key domain on Bash 3.0.
* Search a serialized string table: an experiment was slower than the original loop on Bash 3.2 and was rejected.

## Consequences

The index adds one private shell variable per distinct provider or annotation name. Reset must remove these variables as well as clear the arrays. Changes to the scanner's name domain must update the key encoding and its identity tests.

A trace-budget regression checks that late and absent lookups execute a bounded number of shell commands. Behavioral tests cover identity, resets, first-match behavior, and execution across providers, annotations, filtering, random order and parallel workers. End-to-end timings measure the full run separately from lookup-only experiments.
