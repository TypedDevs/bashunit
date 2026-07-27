#!/usr/bin/env bash

# A data provider runs inside the parallel file worker but outside any test
# body, so its stderr is the plain case that the worker-level redirect used to
# discard. Test-body stderr is a different path: it is merged into the captured
# stdout and already surfaces in the failure block.

function data_provider_noisy() {
  echo "WORKER-SCOPE-DIAGNOSTIC" >&2
  echo "1"
}

# @data_provider data_provider_noisy
function test_uses_a_noisy_provider() {
  assert_equals "1" "$1"
}
