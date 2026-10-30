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
  local output_format="${2:-base64}"
  local -a args=()
  local args_count=0

  # Check for unescaped shell metacharacters that would break eval or cause
  # globbing. Combines the leading-metachar case and the embedded-metachar
  # case into a single regex to avoid a second grep subprocess per call.
  local has_metachar=false
  if [ "$(echo "$input" | "$GREP" -cE '(^|[^\])[|&;*]' || true)" -gt 0 ]; then
    has_metachar=true
  fi

  # An odd trailing backslash escapes eval's closing parenthesis.
  local trailing="${input##*[!\\]}"
  if [ $((${#trailing} % 2)) -eq 1 ]; then
    has_metachar=true
  fi

  # Syntax errors in eval exit its shell; serialize there so expansions run only once.
  if [ "$has_metachar" = false ] && (
    local -a eval_args=()
    local eval_args_count=0
    local arg
    # MSYS reparses compound array assignments and drops expanded carriage returns.
    eval 'for arg in '"$input"'; do
      eval_args[eval_args_count]="$arg"
      eval_args_count=$((eval_args_count + 1))
    done' 2>/dev/null || exit 1
    [ "$eval_args_count" -gt 0 ] || exit 1
    local last_idx=$((eval_args_count - 1))
    if [ -z "${eval_args[$last_idx]}" ]; then
      unset 'eval_args[$last_idx]'
    fi
    for arg in "${eval_args[@]+"${eval_args[@]}"}"; do
      if [ "$output_format" = nul ]; then
        printf '%s\0' "$arg"
      else
        encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
        printf '%s\n' "$encoded_arg"
      fi
    done
  ); then
    return 0
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
  if [ "$in_quotes" = true ]; then
    return 2
  fi
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
  # Keep the original base64 stdout format for callers without a requested transport.
  local arg
  for arg in ${args+"${args[@]}"}; do
    if [ "$output_format" = nul ]; then
      printf '%s\0' "$arg"
    else
      encoded_arg="$(bashunit::helper::encode_base64 "${arg}")"
      printf '%s\n' "$encoded_arg"
    fi
  done
}
