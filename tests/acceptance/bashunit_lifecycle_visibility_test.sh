#!/usr/bin/env bash

function set_up() {
  TEST_DIR=$(mktemp -d)
}

function tear_down() {
  rm -rf "$TEST_DIR"
}

function test_hook_visibility_shows_running_message_in_normal_mode() {
  local test_file="$TEST_DIR/test_hook_visibility_normal.sh"
  cat >"$test_file" <<'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
true
}

function tear_down_after_script() {
true
}

function test_hook_normal_mode() {
assert_same "foo" "foo"
}
EOF

  local output
  # Explicitly disable simple/parallel modes to ensure normal output
  output=$(BASHUNIT_SIMPLE_OUTPUT=false BASHUNIT_PARALLEL_RUN=false ./bashunit "$test_file" 2>&1)

  assert_contains "● set_up_before_script" "$output"
  assert_contains "● tear_down_after_script" "$output"
}

function test_hook_visibility_suppressed_in_failures_only_mode() {
  local test_file="$TEST_DIR/test_hook_visibility_failures.sh"
  cat >"$test_file" <<'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
true
}

function tear_down_after_script() {
true
}

function test_hook_failures_only() {
assert_same "foo" "foo"
}
EOF

  local output
  output=$(./bashunit --failures-only "$test_file" 2>&1)

  assert_not_contains "● set_up_before_script" "$output"
  assert_not_contains "● tear_down_after_script" "$output"
}

function test_hook_visibility_suppressed_in_simple_mode() {
  local test_file="$TEST_DIR/test_hook_visibility_simple.sh"
  cat >"$test_file" <<'EOF'
#!/usr/bin/env bash

function set_up_before_script() {
true
}

function tear_down_after_script() {
true
}

function test_hook_simple_mode() {
assert_same "foo" "foo"
}
EOF

  local output
  # Explicitly set simple mode and disable parallel to test simple output format
  output=$(BASHUNIT_SIMPLE_OUTPUT=true BASHUNIT_PARALLEL_RUN=false ./bashunit --simple "$test_file" 2>&1)

  assert_not_contains "set_up_before_script" "$output"
  assert_not_contains "tear_down_after_script" "$output"
}

function test_hook_visibility_not_shown_when_hooks_not_defined() {
  local test_file="$TEST_DIR/test_no_hooks.sh"
  cat >"$test_file" <<'EOF'
#!/usr/bin/env bash

function test_no_hooks_defined() {
assert_same "foo" "foo"
}
EOF

  local output
  output=$(BASHUNIT_SIMPLE_OUTPUT=false BASHUNIT_PARALLEL_RUN=false ./bashunit "$test_file" 2>&1)

  assert_not_contains "● set_up_before_script" "$output"
  assert_not_contains "● tear_down_after_script" "$output"
}
