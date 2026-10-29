# ADR-015: File ordinals for scratch paths

Status: Accepted

## Context

Folding test paths into filenames can merge distinct files' results and hide failures. Escaping path separators avoids some collisions but can exceed the filesystem's filename limit for valid test paths. Scratch names must also remain free of per-test processes on Bash 3.0.

## Decision

Assign each loaded file its existing dispatch count before starting workers. Workers inherit that ordinal and use it for result directories and hook capture filenames. Keep the existing per-test ordinal within each file.

## Consequences

Scratch names are short and distinct within a run, including for identical basenames and paths containing underscores. They do not depend on process IDs, random values, path length, or external commands. These names are internal and are removed when the run ends.
