#!/usr/bin/env bash

# Entry point for the src/config/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# Run-scoped configuration and the state a run persists: every BASHUNIT_* default
# and its scratch dirs (env), whether this run is parallel and its stop flag
# (parallel), and the last-failed cache the next run reads (rerun). They cluster
# for real -- env reads rerun's setting, parallel reads env's.
#
# env.sh is the one file here that executes at source time: it loads .bashunitrc
# and .env and creates the scratch dirs. Its file-scope block calls only
# bashunit::env:: functions defined above it in the same file, so the order below
# is free -- but this module must stay where parallel.sh and env.sh sat, ahead of
# console/, whose palette is built at file scope from these values.
#
# Note src/config/parallel.sh is a different concern from src/runner/parallel.sh:
# this one answers "is this run parallel", that one waits on job slots.
source "$BASHUNIT_ROOT_DIR/src/config/parallel.sh"
source "$BASHUNIT_ROOT_DIR/src/config/env.sh"
source "$BASHUNIT_ROOT_DIR/src/config/rerun.sh"
source "$BASHUNIT_ROOT_DIR/src/config/suites.sh"
