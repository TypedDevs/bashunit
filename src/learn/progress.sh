#!/usr/bin/env bash

# Lesson completion state, persisted in LEARN_PROGRESS_FILE.

declare -r LEARN_PROGRESS_FILE="$HOME/.bashunit_learn_progress"

##
# Mark lesson as completed
##
function bashunit::learn::mark_completed() {
  local lesson=$1
  echo "$lesson" >>"$LEARN_PROGRESS_FILE"
}


##
# Check if lesson is completed
##
function bashunit::learn::is_completed() {
  local lesson=$1
  [ -f "$LEARN_PROGRESS_FILE" ] && [ "$("$GREP" -c "^$lesson$" "$LEARN_PROGRESS_FILE" || true)" -gt 0 ]
}


##
# Show learning progress
##
function bashunit::learn::show_progress() {
  if [ ! -f "$LEARN_PROGRESS_FILE" ]; then
    echo "${_BASHUNIT_COLOR_INCOMPLETE}No progress yet. Start with lesson 1!${_BASHUNIT_COLOR_DEFAULT}"
    return
  fi

  echo "${_BASHUNIT_COLOR_BOLD}Your Progress:${_BASHUNIT_COLOR_DEFAULT}"
  echo ""

  local total_lessons=10
  local completed=0

  local i
  for i in $(seq 1 $total_lessons); do
    if bashunit::learn::is_completed "lesson_$i"; then
      echo "  ${_BASHUNIT_COLOR_PASSED}✓${_BASHUNIT_COLOR_DEFAULT} Lesson $i completed"
      ((++completed)) || true
    else
      echo "  ${_BASHUNIT_COLOR_INCOMPLETE}○${_BASHUNIT_COLOR_DEFAULT} Lesson $i"
    fi
  done

  echo ""
  echo "Progress: $completed/$total_lessons lessons completed"

  if [ $completed -eq $total_lessons ]; then
    echo ""
    printf "%s%s🎉 Congratulations! You've completed all lessons!%s\n" \
      "$_BASHUNIT_COLOR_PASSED" "$_BASHUNIT_COLOR_BOLD" "$_BASHUNIT_COLOR_DEFAULT"
  fi

  read -p "Press Enter to continue..." -r
}


##
# Reset learning progress
##
function bashunit::learn::reset_progress() {
  rm -f "$LEARN_PROGRESS_FILE"
  echo "${_BASHUNIT_COLOR_PASSED}Progress reset successfully.${_BASHUNIT_COLOR_DEFAULT}"
  read -p "Press Enter to continue..." -r
}

