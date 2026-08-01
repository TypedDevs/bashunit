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
function bashunit::learn::run_lesson_test() {
  local test_file=$1
  local lesson_number=$2

  echo "${_BASHUNIT_COLOR_BOLD}Running your test...${_BASHUNIT_COLOR_DEFAULT}"
  echo ""

  if "$BASHUNIT_ROOT_DIR/bashunit" "$test_file" --simple; then
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

