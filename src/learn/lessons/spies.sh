#!/usr/bin/env bash

# The "spies" lesson.

##
# Lesson 7: Spies
##
function bashunit::learn::lesson_spies() {
  clear
  cat <<'EOF'
╔════════════════════════════════════════════════════════════════╗
║              Lesson 7: Spies - Verifying Calls                 ║
╚════════════════════════════════════════════════════════════════╝

CONCEPT: Spies let you verify that functions were called with specific
arguments or a certain number of times.

KEY DIFFERENCE: Spies track calls without changing behavior, while
mocks (Lesson 6) replace the function entirely with custom behavior.

TASK: Use spies to verify function calls.

File: deploy.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function deploy_app() {
  git push origin main
  docker build -t myapp .
  docker push myapp
}
───────────────────────────────────────────────────────────────

File: deploy_test.sh
───────────────────────────────────────────────────────────────
#!/usr/bin/env bash

function set_up() {
  source deploy.sh
}

function test_deploy_calls_git_push() {
  # TODO: Create spies for git and docker
  # Hint: spy git
  # Hint: spy docker

  deploy_app

  # TODO: Assert git was called
  # Hint: assert_have_been_called git

  # TODO: Assert docker was called
}

function test_deploy_calls_docker_twice() {
  # TODO: Spy on docker

  deploy_app

  # TODO: Assert docker was called exactly 2 times
  # Hint: assert_have_been_called_times 2 docker
}
───────────────────────────────────────────────────────────────

TIPS:
  • Spies track calls but don't change behavior (unlike mocks)
  • assert_have_been_called - verifies at least one call
  • assert_have_been_called_times N - verifies exact call count
  • assert_have_been_called_with - verifies specific arguments
  • Spies are cleaned up automatically after each test
EOF

  local default_file="deploy_test.sh"
  echo ""
  printf "When ready, enter TEST file path %s[%s]%s: " \
    "${_BASHUNIT_COLOR_FAINT}" "$default_file" "${_BASHUNIT_COLOR_DEFAULT}"
  read -r test_file
  test_file="${test_file:-$default_file}"

  if [ ! -f "$test_file" ]; then
    local template='#!/usr/bin/env bash

function set_up() {
  source deploy.sh
}

function test_deploy_calls_git_push() {
  # TODO: Create spies for git and docker
  # Hint: spy git
  # Hint: spy docker

  deploy_app

  # TODO: Assert git was called
  # Hint: assert_have_been_called git

  # TODO: Assert docker was called
}

function test_deploy_calls_docker_twice() {
  # TODO: Spy on docker

  deploy_app

  # TODO: Assert docker was called exactly 2 times
  # Hint: assert_have_been_called_times 2 docker
}'

    bashunit::learn::create_example_file "$test_file" "$template"
    return 1
  fi

  if [ "$("$GREP" -c "spy" "$test_file" || true)" -eq 0 ]; then
    echo "${_BASHUNIT_COLOR_FAILED}Your test should use spy${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi

  bashunit::learn::run_lesson_test "$test_file" 7
}

