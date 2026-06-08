#!/usr/bin/env bash

function bashunit::init::project() {
  local tests_dir="${1:-$BASHUNIT_DEFAULT_PATH}"
  mkdir -p "$tests_dir"

  local bootstrap_file="$tests_dir/bootstrap.sh"
  if [ ! -f "$bootstrap_file" ]; then
    cat >"$bootstrap_file" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Place your common test setup here
SH
    chmod +x "$bootstrap_file"
    echo "> Created $bootstrap_file"
  fi

  local example_test="$tests_dir/example_test.sh"
  if [ ! -f "$example_test" ]; then
    cat >"$example_test" <<'SH'
#!/usr/bin/env bash

function test_bashunit_is_installed() {
  assert_same "bashunit is installed" "bashunit is installed"
}
SH
    chmod +x "$example_test"
    echo "> Created $example_test"
  fi

  local workflow_dir=".github/workflows"
  local workflow_file="$workflow_dir/tests.yml"
  if [ ! -f "$workflow_file" ]; then
    mkdir -p "$workflow_dir"
    cat >"$workflow_file" <<SH
name: Tests
on: [pull_request, push]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: TypedDevs/bashunit@v0
        with:
          args: $tests_dir
SH
    echo "> Created $workflow_file"
  fi

  local env_file=".env"
  local env_line="BASHUNIT_BOOTSTRAP=$bootstrap_file"
  if [ -f "$env_file" ]; then
    if grep -q "^BASHUNIT_BOOTSTRAP=" "$env_file"; then
      if bashunit::check_os::is_macos; then
        sed -i '' -e "s/^BASHUNIT_BOOTSTRAP=/#&/" "$env_file"
      else
        sed -i -e "s/^BASHUNIT_BOOTSTRAP=/#&/" "$env_file"
      fi
    fi
    echo "$env_line" >>"$env_file"
  else
    echo "$env_line" >"$env_file"
  fi

  echo "> bashunit initialized in $tests_dir"
}
