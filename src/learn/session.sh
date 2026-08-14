#!/usr/bin/env bash

# The learning session's scratch directory and the runner that executes a lesson's example test.

LEARN_TEMP_DIR=""

##
# Initialize learning environment
##
function bashunit::learn::init() {
  LEARN_TEMP_DIR=$("${MKTEMP:-mktemp}" -d "${TMPDIR:-/tmp}/bashunit_learn.XXXXXXXX")
  mkdir -p tests
}


##
# Cleanup learning environment
##
function bashunit::learn::cleanup() {
  if [ -n "${LEARN_TEMP_DIR:-}" ] && [ -d "$LEARN_TEMP_DIR" ]; then
    rm -rf "$LEARN_TEMP_DIR"
  fi
}


##
# Create the example file automatically
# Arguments: $1 - filename, $2 - file content
##
function bashunit::learn::create_example_file() {
  local filename=$1
  local content=$2

  echo ""
  echo "Creating example file ${_BASHUNIT_COLOR_BOLD}$filename${_BASHUNIT_COLOR_DEFAULT}..."
  echo "$content" >"$filename"
  chmod +x "$filename"
  echo "${_BASHUNIT_COLOR_PASSED}✓ Created $filename${_BASHUNIT_COLOR_DEFAULT}"
  echo ""
  echo "File created! Edit it to complete the TODO items, then run this lesson again."
  read -p "Press Enter to continue..." -r
  return 0
}


##
# Run a lesson test and check results
##
##
# Counts matches of $2 in $1, ignoring comment lines.
#
# Lessons gate on "did the learner use this API", but the template each lesson
# writes carries the API name in its own TODO/Hint comments -- so a plain grep
# matched the hint and the gate passed before any work was done. All nine gates
# were satisfied by their own untouched template, which also let a learner
# complete a lesson with an unrelated passing assertion (#1258).
# Arguments: $1 - file to search, $2 - pattern
##
function bashunit::learn::count_in_code() {
  local file=$1
  local pattern=$2

  "$GREP" -v '^[[:space:]]*#' "$file" | "$GREP" -c "$pattern" || true
}

function bashunit::learn::run_lesson_test() {
  local test_file=$1
  local lesson_number=$2

  echo "${_BASHUNIT_COLOR_BOLD}Running your test...${_BASHUNIT_COLOR_DEFAULT}"
  echo ""

  # --fail-on-risky, or an untouched template completes the lesson: a test whose
  # body is still only TODO comments records no assertions, which is *risky*,
  # and risky exits 0 by default. The learner is told "Excellent!" for work they
  # have not done (#1256).
  if "$BASHUNIT_ROOT_DIR/bashunit" "$test_file" --simple --fail-on-risky; then
    echo ""
    printf "%s%s✓ Excellent! Lesson %s completed!%s\n" \
      "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_BOLD" "$lesson_number" "$_BASHUNIT_COLOR_DEFAULT"
    bashunit::learn::mark_completed "lesson_$lesson_number"
    read -p "Press Enter to continue..." -r
    return 0
  else
    echo ""
    echo "${_BASHUNIT_COLOR_FAILED}Not quite right. Review the requirements and try again.${_BASHUNIT_COLOR_DEFAULT}"
    read -p "Press Enter to continue..." -r
    return 1
  fi
}

