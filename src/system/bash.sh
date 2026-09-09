#!/usr/bin/env bash

# What the running Bash can do, decided once at load time.
#
# bashunit floors at Bash 3.0, so it forks where a newer shell has a builtin.
# A flag here lets a leaf module ship two bodies for one helper and pick
# between them with a column-0 `if/else`, so a newer shell skips the fork and
# 3.0 keeps working. The floor does not move.
#
# Load time, not call time. Measured over 100k calls, best of 5, against a
# single ungated definition: a top-level `if/else` that picks the definition
# once costs between -0.07 and +0.09 microseconds per call -- nothing -- while
# a predicate function called per use costs +17.9 on Bash 3.0 and +4.3 on 5.3.
#
# The tier lives in the flag name so the compatibility rules can compare a
# construct's minimum version against a gate's declared tier by text alone; see
# adrs/adr-013-bash-version-gated-fast-paths.md for what a gate may and may not
# change, and tests/unit/project/bash_compatibility_test.sh for the enforcement.
#
# Compared major-then-minor rather than as a packed integer, so a two-digit
# minor (5.10) cannot read as a lower tier than 5.3.

_BASHUNIT_BASH_GE_31=0

if [ "${BASH_VERSINFO[0]:-0}" -gt 3 ]; then
  _BASHUNIT_BASH_GE_31=1
elif [ "${BASH_VERSINFO[0]:-0}" -eq 3 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 1 ]; then
  _BASHUNIT_BASH_GE_31=1
fi
