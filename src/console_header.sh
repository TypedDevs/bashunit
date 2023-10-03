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
    printf "%s\n\n" "$BASH_UNIT_VERSION"
  else
    printf "bashunit - %s\n" "$BASH_UNIT_VERSION"
  fi
}


function console_header::print_version_with_env() {
    local should_print_ascii="true"
    if [[ "$SHOW_HEADER" != "$should_print_ascii" ]]; then
      return
    fi
    console_header::print_version
}
