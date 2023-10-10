#!/bin/bash

function console_header::print_version() {
  if [[ $HEADER_ASCII_ART == true ]]; then
    cat <<EOF
 _               _                   _
| |__   __ _ ___| |__  __ __ ____ (_) |_
| '_ \ / _' / __| '_ \| | | | '_ \| | __|
| |_) | (_| \__ \ | | | |_| | | | | | |_
|_.__/ \__,_|___/_| |_|\___/|_| |_|_|\__|
EOF
    printf "%s\n\n" "$BASHUNIT_VERSION"
  else
    printf "${_COLOR_BOLD}${_COLOR_PASSED}bashunit${_COLOR_DEFAULT} - %s\n" "$BASHUNIT_VERSION"
  fi
}

function console_header::print_version_with_env() {
    local should_print_ascii="true"
    if [[ "$SHOW_HEADER" != "$should_print_ascii" ]]; then
      return
    fi
    console_header::print_version
}

function console_header::print_help() {
    cat <<EOF
bashunit [arguments] [options]

${_COLOR_BOLD}Arguments:${_COLOR_DEFAULT}
  ${_COLOR_FAINT}bashunit "directory|file"${_COLOR_DEFAULT}

Specifies the directory or file containing the tests to be run.
If a directory is specified, it will execute tests within files ending in test.sh.
If you use wildcards, bashunit will run any tests it finds.

${_COLOR_BOLD}Options:${_COLOR_DEFAULT}
${_COLOR_BOLD}-f|--filer${_COLOR_DEFAULT} Filters the tests to be run based on the test name.
  ${_COLOR_FAINT}bashunit -f|--filter "test name"${_COLOR_DEFAULT}

${_COLOR_BOLD}-s|simple || -v|verbose${_COLOR_DEFAULT} Enables simplified or verbose output to the console.
  ${_COLOR_FAINT}bashunit -s "test name"${_COLOR_DEFAULT}

${_COLOR_BOLD}--version${_COLOR_DEFAULT} Displays the current version of bashunit.
  ${_COLOR_FAINT}bashunit --version${_COLOR_DEFAULT}

${_COLOR_BOLD}--help${_COLOR_DEFAULT} This message.
EOF
}
