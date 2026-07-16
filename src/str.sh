#!/usr/bin/env bash

_BASHUNIT_STR_STRIPPED_OUT=""

# Strip ANSI escape codes and control characters, writing the result into the
# global slot _BASHUNIT_STR_STRIPPED_OUT (no fork on the plain-text fast path).
# Callers on hot paths (assert_equals/assert_not_equals) use this to avoid the
# per-call command-substitution fork. See bash-style.md (return-slot pattern).
function bashunit::str::strip_ansi_to_slot() {
  local input="$1"
  # Fast path: plain text with no backslash (echo -e no-op) and no control
  # bytes (nothing for sed to strip) passes through unchanged, zero forks.
  case "$input" in
  *\\* | *[[:cntrl:]]*) ;;
  *)
    _BASHUNIT_STR_STRIPPED_OUT=$input
    return
    ;;
  esac
  # Pure-bash path for short strings without backslashes: display lines (e.g.
  # the per-test "✓ Passed … 3ms" alignment on systems whose clock is fork-free)
  # land here, so a colored line does not cost a sed fork per test. Strip
  # CSI sequences segment-wise, then sweep remaining control bytes; the size
  # guard avoids bash's quadratic pattern-substitution on large captures and
  # `*\\*` still defers to `echo -e` semantics below.
  case "$input" in
  *\\*) ;;
  *)
    if [ "${#input}" -le 1024 ]; then
      local out="" rest="$input" params
      while :; do
        case "$rest" in
        *$'\x1b'\[*)
          out="$out${rest%%$'\x1b'\[*}"
          rest="${rest#*$'\x1b'\[}"
          params=""
          while :; do
            case "$rest" in
            [0-9\;]*)
              params="$params${rest%"${rest#?}"}"
              rest="${rest#?}"
              ;;
            *) break ;;
            esac
          done
          case "$rest" in
          # Same finals sed strips; anything else keeps its printable residue
          # (the ESC itself falls to the control-byte sweep, exactly like sed).
          m* | K*) rest="${rest#?}" ;;
          *) out="${out}[${params}" ;;
          esac
          ;;
        *)
          out="$out$rest"
          break
          ;;
        esac
      done
      _BASHUNIT_STR_STRIPPED_OUT=${out//[[:cntrl:]]/}
      return
    fi
    ;;
  esac
  _BASHUNIT_STR_STRIPPED_OUT=$(echo -e "$input" | sed -E 's/\x1B\[[0-9;]*[mK]//g; s/[[:cntrl:]]//g')
}

# Strip ANSI escape codes and control characters, echoing the result.
# Thin wrapper over the return-slot variant for callers that want stdout.
function bashunit::str::strip_ansi() {
  bashunit::str::strip_ansi_to_slot "$1"
  echo "$_BASHUNIT_STR_STRIPPED_OUT"
}

function bashunit::str::rpad() {
  local left_text="$1"
  local right_word="$2"
  local width_padding="${3:-$TERMINAL_WIDTH}"
  # Subtract 1 more to account for the extra space
  local padding=$((width_padding - ${#right_word} - 1))
  if ((padding < 0)); then
    padding=0
  fi

  # Remove ANSI escape sequences (non-visible characters) for length calculation
  bashunit::str::strip_ansi_to_slot "$left_text"
  local clean_left_text=$_BASHUNIT_STR_STRIPPED_OUT

  local is_truncated=false
  # If the visible left text exceeds the padding, truncate it and add "..."
  if [ ${#clean_left_text} -gt $padding ]; then
    local truncation_length=$((padding < 3 ? 0 : padding - 3))
    clean_left_text="${clean_left_text:0:$truncation_length}"
    is_truncated=true
  fi

  local result_left_text
  local remaining_space
  if $is_truncated; then
    # Rebuild char-by-char with ANSI codes intact, applying the truncation.
    result_left_text=""
    local i=0
    local j=0
    while [ $i -lt ${#clean_left_text} ] && [ $j -lt ${#left_text} ]; do
      local char="${clean_left_text:$i:1}"
      local original_char="${left_text:$j:1}"

      # If the current character is part of an ANSI sequence, skip it and copy it
      if [ "$original_char" = $'\x1b' ]; then
        while [ "${left_text:$j:1}" != "m" ] && [ $j -lt ${#left_text} ]; do
          result_left_text="$result_left_text${left_text:$j:1}"
          ((++j))
        done
        result_left_text="$result_left_text${left_text:$j:1}" # Append the final 'm'
        ((++j))
      elif [ "$char" = "$original_char" ]; then
        # Match the actual character
        result_left_text="$result_left_text$char"
        ((++i))
        ((++j))
      else
        ((++j))
      fi
    done
    result_left_text="$result_left_text..."
    # 1: due to a blank space
    # 3: due to the appended ...
    remaining_space=$((width_padding - ${#clean_left_text} - ${#right_word} - 1 - 3))
  else
    # Not truncated: the visible text fits, so the original (ANSI intact) is
    # already correct — skip the per-character rebuild entirely.
    result_left_text="$left_text"
    remaining_space=$((width_padding - ${#clean_left_text} - ${#right_word} - 1))
  fi

  # Ensure the right word is placed exactly at the far right of the screen
  # filling the remaining space with padding
  if [ $remaining_space -lt 0 ]; then
    remaining_space=0
  fi

  printf "%s%${remaining_space}s %s\n" "$result_left_text" "" "$right_word"
}
