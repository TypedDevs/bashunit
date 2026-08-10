#!/usr/bin/env bash

# Entry point for the src/reports/ module. `source` lines and comments only,
# for the reason recorded in adrs/adr-011-source-layout-and-build-pipeline.md.
#
# collect.sh holds the shared result arrays; each writer reads them and nothing
# else, so the layering is one level deep.
source "$BASHUNIT_ROOT_DIR/src/reports/collect.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/junit.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/tap.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/json.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/gha.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/html.sh"
source "$BASHUNIT_ROOT_DIR/src/reports/markdown.sh"
