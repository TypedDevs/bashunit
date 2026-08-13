#!/usr/bin/env bash

function bashunit::runner::parse_data_provider_args() {
  local input="$1"
  local current_arg=""
  local in_quotes=false
  local had_quotes=false # Track if arg was quoted (to preserve empty quoted strings)
  local quote_char=""
  local escaped=false
  local IFS=$' \t\n'
  local i=0
  local arg=""
  local encoded_arg
  local -a args=()
  local args_count=0

  # Check for unescaped shell metacharacters that would break eval or cause
  # globbing. Combines the leading-metachar case and the embedded-metachar
  # case into a single regex to avoid a second grep subprocess per call.
  local has_metachar=false
  if [ "$(echo "$input" | "$GREP" -cE '(^|[^\])[|&;*]' || true)" -gt 0 ]; then
    has_metachar=true
  fi

  # An odd run of trailing backslashes escapes the `)` the eval below adds, so
  # eval sees `args=(C:\)` -- unterminated, a SYNTAX error rather than a failed
  # command. Inside a command substitution, which is how exec.sh calls this,
  # that kills the subshell: no output, and the argument reaches the test unset
  # instead of as `C:` (#1134). The fallback parser handles it, so skip eval.
  local trailing="${input##*[!\\]}"
  if [ $((${#trailing} % 2)) -eq 1 ]; then
    has_metachar=true
  fi

  # Try eval first (needed for $'...' from printf '%q'), unless metacharacters present
  if [ "$has_metachar" = false ] && eval "args=($input)" 2>/dev/null; then
    # Check if args has elements after eval
    args_count=0
    local _tmp arg
    for _tmp in ${args+"${args[@]}"}; do args_count=$((args_count + 1)); done
    if [ "$args_count" -gt 0 ]; then
      # Successfully parsed - remove sentinel if present
      local last_idx=$((args_count - 1))
      if [ -z "${args[$last_idx]}" ]; then
        unset 'args[$last_idx]'
      fi
      # Print args and return early
      for arg in "${args[@]+"${args[@]}"}"; do
        encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
        printf '%s\n' "$encoded_arg"
      done
      return
    fi
  fi

  # Fallback: parse args from the input string into an array, respecting quotes and escapes
  local i
  for ((i = 0; i < ${#input}; i++)); do
    local char="${input:$i:1}"
    if [ "$escaped" = true ]; then
      case "$char" in
      t) current_arg="$current_arg"$'\t' ;;
      n) current_arg="$current_arg"$'\n' ;;
      *) current_arg="$current_arg$char" ;;
      esac
      escaped=false
    elif [ "$char" = "\\" ]; then
      escaped=true
    elif [ "$in_quotes" = false ]; then
      case "$char" in
      "$")
        # Handle $'...' syntax
        if [ "${input:$i:2}" = "$'" ]; then
          in_quotes=true
          had_quotes=true
          quote_char="'"
          # Skip the $
          i=$((i + 1))
        else
          current_arg="$current_arg$char"
        fi
        ;;
      "'" | '"')
        in_quotes=true
        had_quotes=true
        quote_char="$char"
        ;;
      " " | $'\t')
        # Add if non-empty OR if was quoted (to preserve empty quoted strings like '')
        if [ -n "$current_arg" ] || [ "$had_quotes" = true ]; then
          args[args_count]="$current_arg"
          args_count=$((args_count + 1))
        fi
        current_arg=""
        had_quotes=false
        ;;
      *)
        current_arg="$current_arg$char"
        ;;
      esac
    elif [ "$char" = "$quote_char" ]; then
      in_quotes=false
      quote_char=""
    else
      current_arg="$current_arg$char"
    fi
  done
  args[args_count]="$current_arg"
  args_count=$((args_count + 1))
  # Remove all trailing empty strings
  while [ "$args_count" -gt 0 ]; do
    local last_idx=$((args_count - 1))
    if [ -z "${args[$last_idx]}" ]; then
      unset 'args[$last_idx]'
      args_count=$((args_count - 1))
    else
      break
    fi
  done
  # Print one arg per line to stdout, base64-encoded to preserve newlines in the data
  local arg
  for arg in ${args+"${args[@]}"}; do
    encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
    printf '%s\n' "$encoded_arg"
  done
}
