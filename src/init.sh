#!/usr/bin/env bash

function init::init() {
  local tests_dir="$BASHUNIT_DEFAULT_PATH"
  mkdir -p "$tests_dir"

  local bootstrap_file="$tests_dir/bootstrap.sh"
  if [[ ! -f "$bootstrap_file" ]]; then
    cat >"$bootstrap_file" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Place your common test setup here
SH
    chmod +x "$bootstrap_file"
    echo "> Created $bootstrap_file"
  fi

  local example_test="$tests_dir/example_test.sh"
  if [[ ! -f "$example_test" ]]; then
    cat >"$example_test" <<'SH'
#!/usr/bin/env bash

function test_bashunit_is_installed() {
  assert_same "bashunit is installed" "bashunit is installed"
}
SH
    chmod +x "$example_test"
    echo "> Created $example_test"
  fi

  echo "> bashunit initialized in $tests_dir"
}
