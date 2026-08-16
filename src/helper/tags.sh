#!/usr/bin/env bash

# @tag extraction and matching.

# Every tag seen this run, comma separated. Accumulated as each file is scanned
# so an empty --tag selection can name the tags that exist (#1265).
_BASHUNIT_SEEN_TAGS=""

#
# Scans a script once and caches its test-function -> tags pairs.
# Memoized by resolved path, so repeated calls for the same file do not rescan.
# Arguments: $1 - path to the test script
#
function bashunit::helper::build_tags_map() {
  local script=$1
  # Handle directory changes in set_up_before_script (issue #529)
  if [ ! -f "$script" ] && [ -n "${BASHUNIT_WORKING_DIR:-}" ]; then
    script="$BASHUNIT_WORKING_DIR/$script"
  fi

  if [ ! -f "$script" ]; then
    # Unreadable path: reset to an empty map keyed to this argument so a
    # follow-up lookup returns empty without rescanning.
    _BASHUNIT_TAGS_MAP_SCRIPT="$1"
    _BASHUNIT_TAGS_MAP_FNS=()
    _BASHUNIT_TAGS_MAP_TAGS=()
    return
  fi

  if [ "$script" = "$_BASHUNIT_TAGS_MAP_SCRIPT" ]; then
    return
  fi

  _BASHUNIT_TAGS_MAP_SCRIPT="$script"
  _BASHUNIT_TAGS_MAP_FNS=()
  _BASHUNIT_TAGS_MAP_TAGS=()

  local count=0
  local fn tags
  # Single awk pass emits "<fn>\t<tags>" for every function that carries at
  # least one `# @tag <name>` comment in the contiguous comment block directly
  # above its definition, mirroring the previous per-function backward walk.
  # Tags accumulate nearest-to-the-function first (same order the old walk
  # produced). A blank or non-comment line breaks the association; other
  # comment lines keep the block open. Both `function test_x` and `test_x()`
  # definition styles are recognised.
  # Here-string, not `< <(awk …)`: the same per-file descriptor leak documented
  # in helper/provider.sh applies here whenever --tag is used (#1271).
  while IFS=$'\t' read -r fn tags; do
    [ -z "$fn" ] && continue
    _BASHUNIT_TAGS_MAP_FNS[count]="$fn"
    _BASHUNIT_TAGS_MAP_TAGS[count]="$tags"
    # Remember every tag the run has seen, so a --tag that selects nothing can
    # name the ones that exist. The map itself is cached per script, so only
    # the last file's would survive to the summary. Tags are user-defined
    # strings with no other way to list them, which is what makes a typo a
    # dead end (#1265). Per file, not per test: build_tags_map is cached.
    local _seen_tag
    local _old_ifs=$IFS
    IFS=','
    for _seen_tag in $tags; do
      case ",$_BASHUNIT_SEEN_TAGS," in
      *",$_seen_tag,"*) ;;
      *) _BASHUNIT_SEEN_TAGS="${_BASHUNIT_SEEN_TAGS:+$_BASHUNIT_SEEN_TAGS,}$_seen_tag" ;;
      esac
    done
    IFS=$_old_ifs
    count=$((count + 1))
  done <<<"$(awk '
    # An uninitialised awk variable used as a subscript is the empty string,
    # not 0, so the first function would land in order[""] and be unreachable
    # from the numeric loop in END.
    BEGIN { n = 0 }
    # File-level tags: `# @tags a b` applies to every test in the file. Checked
    # before the singular rule and before the generic comment rule, and space
    # separated because it is a list rather than one tag per line.
    /^[[:space:]]*#[[:space:]]*@tags[[:space:]]/ {
      t = $0
      sub(/^[[:space:]]*#[[:space:]]*@tags[[:space:]]+/, "", t)
      sub(/[[:space:]]+$/, "", t)
      gsub(/[[:space:]]+/, ",", t)
      if (t != "") { filetags = (filetags == "" ? t : filetags "," t) }
      next
    }
    /^[[:space:]]*#[[:space:]]*@tag[[:space:]]/ {
      t = $0
      sub(/^[[:space:]]*#[[:space:]]*@tag[[:space:]]+/, "", t)
      tags = (tags == "" ? t : t "," tags)
      next
    }
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*(function[[:space:]]+)?[A-Za-z_][A-Za-z0-9_:]*[[:space:]]*\(\)/ {
      fn = $0
      sub(/^[[:space:]]*(function[[:space:]]+)?/, "", fn)
      sub(/[[:space:]]*\(\).*/, "", fn)
      # Buffered rather than printed here so a `# @tags` line placed below the
      # functions still applies to them (single pass, order preserved).
      order[n] = fn
      own[n] = tags
      n++
      tags = ""
      next
    }
    { tags = "" }
    END {
      for (i = 0; i < n; i++) {
        combined = own[i]
        if (filetags != "") {
          combined = (combined == "" ? filetags : combined "," filetags)
        }
        if (combined == "") { continue }
        # Function tags come first (nearest-first, as before); a tag carried at
        # both levels is emitted once.
        count = split(combined, parts, ",")
        out = ""
        delete seen
        for (j = 1; j <= count; j++) {
          if (parts[j] == "" || (parts[j] in seen)) { continue }
          seen[parts[j]] = 1
          out = (out == "" ? parts[j] : out "," parts[j])
        }
        if (out != "") { printf "%s\t%s\n", order[i], out }
      }
    }
  ' "$script" 2>/dev/null)"
}


#
# Pure-bash lookup against the cached tags map.
# Writes the comma-separated tags (or empty) into _BASHUNIT_TAGS_OUT.
# Arguments: $1 - test-function name
#
function bashunit::helper::tags_for_function() {
  local function_name=$1
  local i=0
  local total=${#_BASHUNIT_TAGS_MAP_FNS[@]}
  while [ "$i" -lt "$total" ]; do
    if [ "${_BASHUNIT_TAGS_MAP_FNS[i]}" = "$function_name" ]; then
      _BASHUNIT_TAGS_OUT="${_BASHUNIT_TAGS_MAP_TAGS[i]}"
      return
    fi
    i=$((i + 1))
  done
  _BASHUNIT_TAGS_OUT=""
}


#
# Whether a comma-separated tag list contains an exact tag.
# A tag may itself contain spaces (`# @tag needs a db`), so the split is on
# commas only.
# Arguments: $1 - comma-separated tags, $2 - tag to find
#
function bashunit::helper::_tags_contain() {
  local fn_tags="$1"
  local needle="$2"
  local IFS=','
  local tag
  for tag in $fn_tags; do
    if [ "$tag" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

#
# Evaluates one tag expression against a function's tags.
# An expression is `term` or `term&&term&&...`, where a term is a tag name
# optionally prefixed with `!` to negate it. Surrounding whitespace is ignored.
# A malformed term (empty, or a bare `!`) matches nothing; the CLI rejects those
# up front so they cannot silently widen a selection.
# Arguments: $1 - comma-separated tags for the function, $2 - the expression
# Returns: 0 when the expression holds, 1 otherwise
#
function bashunit::helper::tag_expression_matches() {
  local fn_tags="$1"
  local rest="$2"

  # Always consume one term per iteration and stop only after the last one, so
  # a trailing separator (`a&&`) yields a final empty term and is rejected. A
  # `while [ -n "$rest" ]` loop would silently treat `a&&` as `a`, and an empty
  # expression as "matches everything".
  local term negate more=true
  while [ "$more" = true ]; do
    case "$rest" in
    *"&&"*)
      term="${rest%%&&*}"
      rest="${rest#*&&}"
      ;;
    *)
      term="$rest"
      rest=""
      more=false
      ;;
    esac

    term="${term#"${term%%[![:space:]]*}"}"
    term="${term%"${term##*[![:space:]]}"}"

    negate=false
    case "$term" in
    '!'*)
      negate=true
      term="${term#!}"
      term="${term#"${term%%[![:space:]]*}"}"
      ;;
    esac

    if [ -z "$term" ]; then
      return 1
    fi

    if bashunit::helper::_tags_contain "$fn_tags" "$term"; then
      if [ "$negate" = true ]; then
        return 1
      fi
    elif [ "$negate" = false ]; then
      return 1
    fi
  done

  return 0
}

#
# Checks if a function's tags match the include/exclude filters.
# Include is a comma-separated list of expressions, OR'd together: repeated
# --tag flags arrive comma-joined, so plain tags keep their previous meaning.
# Exclude uses OR logic (any match fails) and takes precedence over include.
# Arguments: $1 - comma-separated tags for the function,
#            $2 - comma-separated include expressions (empty = no filter),
#            $3 - comma-separated exclude tags (empty = no filter)
# Returns: 0 if the function should run, 1 if it should be skipped
#
function bashunit::helper::function_matches_tags() {
  local fn_tags="$1"
  local include_tags="$2"
  local exclude_tags="$3"

  # Check exclude tags first (exclude wins over include)
  if [ -n "$exclude_tags" ]; then
    local IFS=','
    local etag
    for etag in $exclude_tags; do
      local check_tag
      for check_tag in $fn_tags; do
        if [ "$check_tag" = "$etag" ]; then
          return 1
        fi
      done
    done
  fi

  # Check include expressions (OR logic: any match passes). An untagged
  # function is not short-circuited here any more: `!slow` must match it.
  if [ -n "$include_tags" ]; then
    local IFS=','
    local expression
    for expression in $include_tags; do
      if bashunit::helper::tag_expression_matches "$fn_tags" "$expression"; then
        return 0
      fi
    done
    return 1
  fi

  return 0
}
