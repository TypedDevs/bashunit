#!/bin/bash

callTestFunctions() {
    # shellcheck disable=SC2034
    local script="$1"
    local prefix="test"

    # Use declare -F to list all function names
    local function_names
    function_names=$(declare -F | awk '{print $3}')

    for func_name in $function_names; do
        if [[ $func_name == ${prefix}* ]]; then
            "$func_name" # Call the function
            unset "$func_name"
        fi
    done
}

# Check if an argument is provided and assign it to TEST_SCRIPTS
if [ $# -eq 0 ]; then
    echo "Usage: $0 <test_script>"
    exit 1
fi

TEST_SCRIPTS=("$@")

# Loop through the test scripts and call test functions
for test_script in "${TEST_SCRIPTS[@]}"; do
  echo "Running $test_script"
  # shellcheck disable=SC1090
  source "$test_script"
  callTestFunctions "$test_script"
done
