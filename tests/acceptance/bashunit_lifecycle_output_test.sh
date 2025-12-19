#!/usr/bin/env bash

function set_up() {
  TEST_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

function test_lifecycle_functions_do_not_output_without_verbose() {
  local test_file="$TEST_DIR/test_lifecycle.sh"
  cat > "$test_file" << 'EOF'
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
  cat > "$test_file" << 'EOF'
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

function test_hook_visibility_shows_running_message_in_normal_mode() {
  local test_file="$TEST_DIR/test_hook_visibility.sh"
  cat > "$test_file" << 'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
  true
}

function tear_down_after_script() {
  true
}

function test_dummy() {
  assert_same "foo" "foo"
}
EOF

  local output
  # Explicitly disable simple/parallel modes to ensure normal output
  output=$(BASHUNIT_SIMPLE_OUTPUT=false BASHUNIT_PARALLEL_RUN=false ./bashunit "$test_file" 2>&1)

  assert_contains "Running set_up_before_script..." "$output"
  assert_contains "done" "$output"
  assert_contains "Running tear_down_after_script..." "$output"
}

function test_hook_visibility_suppressed_in_failures_only_mode() {
  local test_file="$TEST_DIR/test_hook_visibility.sh"
  cat > "$test_file" << 'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
  true
}

function tear_down_after_script() {
  true
}

function test_dummy() {
  assert_same "foo" "foo"
}
EOF

  local output
  output=$(./bashunit --failures-only "$test_file" 2>&1)

  assert_not_contains "Running set_up_before_script" "$output"
  assert_not_contains "Running tear_down_after_script" "$output"
}

function test_hook_visibility_abbreviated_in_simple_mode() {
  local test_file="$TEST_DIR/test_hook_visibility.sh"
  cat > "$test_file" << 'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
  true
}

function tear_down_after_script() {
  true
}

function test_dummy() {
  assert_same "foo" "foo"
}
EOF

  local output
  # Explicitly set simple mode and disable parallel to test simple output format
  output=$(BASHUNIT_SIMPLE_OUTPUT=true BASHUNIT_PARALLEL_RUN=false ./bashunit --simple "$test_file" 2>&1)

  assert_contains "[set_up_before_script..." "$output"
  assert_contains "[tear_down_after_script..." "$output"
  assert_not_contains "Running set_up_before_script..." "$output"
}

function test_hook_visibility_not_shown_when_hooks_not_defined() {
  local test_file="$TEST_DIR/test_no_hooks.sh"
  cat > "$test_file" << 'EOF'
#!/usr/bin/env bash

function test_dummy() {
  assert_same "foo" "foo"
}
EOF

  local output
  output=$(./bashunit "$test_file" 2>&1)

  assert_not_contains "Running set_up_before_script" "$output"
  assert_not_contains "Running tear_down_after_script" "$output"
}
