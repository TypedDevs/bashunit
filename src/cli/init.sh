#!/usr/bin/env bash

# Appends `line` to .env, leaves the file alone when it already holds it, and
# comments an older, different `KEY=` out first. Commenting the line out and
# appending an identical one made every re-init add a dead line, so a third
# run left three (#1175); -Fx so a dot in the path is compared literally.
function bashunit::init::write_env_line() {
  local env_file=".env"
  local line=$1
  local key=${line%%=*}
  if [ ! -f "$env_file" ]; then
    printf '%s\n' "$line" >"$env_file"
    echo "> Created $env_file"
    return
  fi
  if grep -Fxq "$line" "$env_file"; then
    echo "> $env_file already sets $key"
    return
  fi
  if grep -q "^$key=" "$env_file"; then
    if bashunit::check_os::is_macos; then
      sed -i '' -e "s/^$key=/#&/" "$env_file"
    else
      sed -i -e "s/^$key=/#&/" "$env_file"
    fi
  fi
  printf '%s\n' "$line" >>"$env_file"
  echo "> Updated $env_file"
}

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

  # .env is sourced as shell, so values are written double-quoted and the
  # characters that are special inside double quotes are escaped: a directory
  # with a space stays one assignment instead of turning into a command.
  local quoted="$tests_dir"
  quoted=${quoted//\\/\\\\}
  quoted=${quoted//\"/\\\"}
  quoted=${quoted//\$/\\\$}
  quoted=${quoted//\`/\\\`}
  bashunit::init::write_env_line "BASHUNIT_BOOTSTRAP=\"$quoted/bootstrap.sh\""
  # A custom directory is otherwise invisible to the next bare `bashunit`,
  # which searches BASHUNIT_DEFAULT_PATH ("tests").
  if [ "$tests_dir" != "$BASHUNIT_DEFAULT_PATH" ]; then
    bashunit::init::write_env_line "BASHUNIT_DEFAULT_PATH=\"$quoted\""
  fi

  echo "> bashunit initialized in $tests_dir"
}
