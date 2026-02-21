#!/usr/bin/env bash

function set_up() {
  TEST_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

function test_lifecycle_functions_do_not_output_without_verbose() {
  local test_file="$TEST_DIR/test_lifecycle.sh"
  cat >"$test_file" <<'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
echo "stdout from set_up_before_script"
echo "stderr from set_up_before_script" >&2
}

function tear_down_after_script() {
echo "stdout from tear_down_after_script"
echo "stderr from tear_down_after_script" >&2
}

function set_up() {
echo "stdout from set_up"
echo "stderr from set_up" >&2
}

function tear_down() {
echo "stdout from tear_down"
echo "stderr from tear_down" >&2
}

function test_no_verbose_example() {
echo "stdout from test"
echo "stderr from test" >&2
assert_same "a" "a"
}
EOF

  local output
  output=$(./bashunit "$test_file" 2>&1)

  assert_not_contains "stdout from set_up_before_script" "$output"
  assert_not_contains "stderr from set_up_before_script" "$output"
  assert_not_contains "stdout from tear_down_after_script" "$output"
  assert_not_contains "stderr from tear_down_after_script" "$output"
  assert_not_contains "stdout from set_up" "$output"
  assert_not_contains "stderr from set_up" "$output"
  assert_not_contains "stdout from tear_down" "$output"
  assert_not_contains "stderr from tear_down" "$output"
  assert_not_contains "stdout from test" "$output"
  assert_not_contains "stderr from test" "$output"
}

function test_lifecycle_functions_output_with_verbose() {
  local test_file="$TEST_DIR/test_lifecycle.sh"
  cat >"$test_file" <<'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
echo "stdout from set_up_before_script"
echo "stderr from set_up_before_script" >&2
}

function tear_down_after_script() {
echo "stdout from tear_down_after_script"
echo "stderr from tear_down_after_script" >&2
}

function set_up() {
echo "stdout from set_up"
echo "stderr from set_up" >&2
}

function tear_down() {
echo "stdout from tear_down"
echo "stderr from tear_down" >&2
}

function test_verbose_example() {
echo "stdout from test"
echo "stderr from test" >&2
assert_same "a" "a"
}
EOF

  local output
  output=$(./bashunit -vvv "$test_file" 2>&1)

  assert_contains "stdout from set_up_before_script" "$output"
  assert_contains "stderr from set_up_before_script" "$output"
  assert_contains "stdout from tear_down_after_script" "$output"
  assert_contains "stderr from tear_down_after_script" "$output"
  assert_contains "stdout from set_up" "$output"
  assert_contains "stderr from set_up" "$output"
  assert_contains "stdout from tear_down" "$output"
  assert_contains "stderr from tear_down" "$output"
  assert_contains "stdout from test" "$output"
  assert_contains "stderr from test" "$output"
}
