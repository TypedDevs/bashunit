#!/usr/bin/env bash

function bashunit::math::calculate() {
  local expr="$*"

  if bashunit::dependencies::has_bc; then
    echo "$expr" | bc
    return
  fi

  case "$expr" in
  *.*)
    if bashunit::dependencies::has_awk; then
      awk "BEGIN { print ($expr) }"
      return
    fi
    # Downgrade to integer math by stripping decimals
    expr=$(echo "$expr" | sed -E 's/([0-9]+)\.[0-9]+/\1/g')
    ;;
  esac

  # Remove leading zeros from integers so $((...)) does not read them as octal.
  # Only fork sed when a leading zero is actually present — the common callers
  # (clock durations) never produce one, so the no-bc path stays fork-free.
  case "$expr" in
  0[0-9]* | *[!0-9.]0[0-9]*)
    expr=$(echo "$expr" | sed -E 's/\b0*([1-9][0-9]*)/\1/g')
    ;;
  esac

  local result=$((expr))
  echo "$result"
}

_BASHUNIT_MATH_PADDED_OUT=""

##
# Pads $1 to exactly $2 decimal places into _BASHUNIT_MATH_PADDED_OUT, so a set
# of operands can be scaled against one shared power of ten. Pure string work,
# no fork and no arithmetic, so it is safe on any operand shape.
# Arguments: $1 - decimal operand, $2 - target number of decimal places
##
function bashunit::math::pad_to_slot() {
  local value=$1
  local places=$2

  case "$value" in
  *.*) ;;
  *) value="${value}." ;;
  esac

  local frac=${value#*.}
  while [ ${#frac} -lt "$places" ]; do
    frac="${frac}0"
  done

  _BASHUNIT_MATH_PADDED_OUT="${value%%.*}.$frac"
}

_BASHUNIT_MATH_DECIMALS_OUT=0

##
# Number of decimal places in $1 into _BASHUNIT_MATH_DECIMALS_OUT, or 0 when it
# has none. A slot rather than an echo: the caller needs this three times per
# assertion, and three `$( )` captures would cost more than the two `bc` forks
# this whole path exists to avoid.
# Arguments: $1 - decimal operand
##
function bashunit::math::decimals_to_slot() {
  local frac
  case "$1" in
  *.*)
    frac=${1#*.}
    _BASHUNIT_MATH_DECIMALS_OUT=${#frac}
    ;;
  *) _BASHUNIT_MATH_DECIMALS_OUT=0 ;;
  esac
}

_BASHUNIT_MATH_SCALED_L_OUT=""
_BASHUNIT_MATH_SCALED_R_OUT=""

##
# Scales two decimal operands to a common integer scale so they can be compared
# with plain `[ ]` arithmetic, writing them into
# _BASHUNIT_MATH_SCALED_L_OUT / _BASHUNIT_MATH_SCALED_R_OUT. No fork: the
# alternative is `bc` or `awk`, and both this and bashunit::math::is_le sit on a
# per-assertion path where that costs a subshell plus a process.
#
# Deliberately narrow. It handles a plain decimal with an optional sign and
# nothing else, and refuses anything it cannot represent exactly in 64-bit
# integer arithmetic, so callers keep their existing bc/awk chain as a fallback
# rather than this quietly returning a wrong answer.
#
# Arguments: $1 - left operand, $2 - right operand
# Returns: 0 and sets both slots, 1 when the pair must go to the fallback
##
function bashunit::math::scale_pair_to_slots() {
  local left=$1 right=$2

  # Exponent notation and anything non-numeric goes to the fallback.
  case "$left$right" in
  '' | *[!0-9.+-]* | *e* | *E*) return 1 ;;
  esac

  local left_sign=1 right_sign=1
  case "$left" in
  -*) left_sign=-1 left=${left#-} ;;
  +*) left=${left#+} ;;
  esac
  case "$right" in
  -*) right_sign=-1 right=${right#-} ;;
  +*) right=${right#+} ;;
  esac
  # A sign anywhere but the front is not a plain decimal.
  case "$left$right" in
  *-* | *+*) return 1 ;;
  esac

  local left_int left_frac right_int right_frac
  case "$left" in
  *.*) left_int=${left%%.*} left_frac=${left#*.} ;;
  *) left_int=$left left_frac="" ;;
  esac
  case "$right" in
  *.*) right_int=${right%%.*} right_frac=${right#*.} ;;
  *) right_int=$right right_frac="" ;;
  esac
  # A second dot survives the split above.
  case "$left_int$left_frac$right_int$right_frac" in
  *.*) return 1 ;;
  esac

  left_int=${left_int:-0}
  right_int=${right_int:-0}

  # Pad the shorter fraction so both sides share one scale.
  while [ ${#left_frac} -lt ${#right_frac} ]; do left_frac="${left_frac}0"; done
  while [ ${#right_frac} -lt ${#left_frac} ]; do right_frac="${right_frac}0"; done

  # 18 digits keeps the scaled value inside a signed 64-bit integer.
  if [ $((${#left_int} + ${#left_frac})) -gt 18 ] ||
    [ $((${#right_int} + ${#right_frac})) -gt 18 ]; then
    return 1
  fi

  # Strip leading zeros; $(( )) reads a leading zero as octal.
  while [ ${#left_int} -gt 1 ]; do
    case "$left_int" in 0*) left_int=${left_int#0} ;; *) break ;; esac
  done
  while [ ${#right_int} -gt 1 ]; do
    case "$right_int" in 0*) right_int=${right_int#0} ;; *) break ;; esac
  done
  local left_frac_value=${left_frac:-0} right_frac_value=${right_frac:-0}
  while [ ${#left_frac_value} -gt 1 ]; do
    case "$left_frac_value" in 0*) left_frac_value=${left_frac_value#0} ;; *) break ;; esac
  done
  while [ ${#right_frac_value} -gt 1 ]; do
    case "$right_frac_value" in 0*) right_frac_value=${right_frac_value#0} ;; *) break ;; esac
  done

  local power=1 i=0
  while [ "$i" -lt ${#left_frac} ]; do
    power=$((power * 10))
    i=$((i + 1))
  done

  _BASHUNIT_MATH_SCALED_L_OUT=$((left_sign * (left_int * power + left_frac_value)))
  _BASHUNIT_MATH_SCALED_R_OUT=$((right_sign * (right_int * power + right_frac_value)))
}

##
# Numeric <= comparison that tolerates decimal operands. Plain `[ -le ]`
# exits 2 ("integer expression expected") on a fractional value instead of
# comparing it, which silently mis-reports the wrong side as failing (see
# bashunit::benchmark::print_results, whose `@max_ms` annotation allows
# decimals). Mirrors bashunit::math::calculate's bc > awk > integer fallback
# chain.
# Arguments: $1 - left operand, $2 - right operand
# Returns: 0 when $1 <= $2, 1 otherwise
##
function bashunit::math::is_le() {
  local left="$1"
  local right="$2"

  # Fork-free for plain decimals, which is nearly all of them.
  if bashunit::math::scale_pair_to_slots "$left" "$right"; then
    [ "$_BASHUNIT_MATH_SCALED_L_OUT" -le "$_BASHUNIT_MATH_SCALED_R_OUT" ]
    return
  fi

  if bashunit::dependencies::has_bc; then
    [ "$(echo "$left <= $right" | bc)" = "1" ]
    return
  fi

  if bashunit::dependencies::has_awk; then
    awk -v a="$left" -v b="$right" 'BEGIN { exit !(a <= b) }'
    return
  fi

  # Downgrade to integer comparison by stripping decimals, matching
  # bashunit::math::calculate's no-bc/no-awk fallback.
  left=$(echo "$left" | sed -E 's/([0-9]+)\.[0-9]+/\1/g')
  right=$(echo "$right" | sed -E 's/([0-9]+)\.[0-9]+/\1/g')
  [ "$left" -le "$right" ]
}

##
# Deterministically shuffles stdin lines (one item per line) with a Fisher-Yates
# driven by a seeded LCG (glibc constants). Same seed + same input always yields
# the same permutation, so a randomized run can be replayed via its seed.
# Self-contained (seeds a local state), so it is safe inside subshells/pipes and
# in --parallel where each test file shuffles in its own forked shell.
# Arguments: $1 - integer seed (non-numeric treated as 0)
##
function bashunit::math::shuffle() {
  local seed=$1
  case "$seed" in '' | *[!0-9]*) seed=0 ;; esac
  local state=$((seed & 2147483647))

  local -a items=()
  local n=0
  local line
  # `|| [ -n "$line" ]` keeps the final item when stdin has no trailing newline.
  while IFS= read -r line || [ -n "$line" ]; do
    items[n]=$line
    n=$((n + 1))
  done

  local i j tmp
  i=$((n - 1))
  while [ "$i" -gt 0 ]; do
    state=$(((1103515245 * state + 12345) & 2147483647))
    j=$((state % (i + 1)))
    tmp=${items[i]}
    items[i]=${items[j]}
    items[j]=$tmp
    i=$((i - 1))
  done

  local k=0
  while [ "$k" -lt "$n" ]; do
    printf '%s\n' "${items[k]}"
    k=$((k + 1))
  done
}
