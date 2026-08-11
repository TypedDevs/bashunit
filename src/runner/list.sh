#!/usr/bin/env bash

# `--list` / `--dry-run`: report which tests a run would execute, without
# executing any of them (#1007).
#
# The listing hooks into load_test_files *after* every selection step (file
# shuffle, --filter, definition-line ordering, --tag/--exclude-tag,
# --rerun-failed, --shard) and *before* render_running_file_header and
# set_up_before_script, so a listed run has no side effects beyond sourcing the
# test files. Ordering comes from runner::order_functions_for_script, the same
# helper the runner uses, so the two cannot disagree about what a seed means.

# JSON items are buffered because the document wraps them; text is streamed.
_BASHUNIT_LIST_JSON_ITEMS=""
_BASHUNIT_LIST_COUNT=0

function bashunit::runner::list_reset() {
  _BASHUNIT_LIST_JSON_ITEMS=""
  _BASHUNIT_LIST_COUNT=0
}

##
# Emits one file's selected test functions in run order.
# Arguments: $1 script path, $2 space-separated test function names
##
function bashunit::runner::list_functions() {
  local script="$1"
  local fns="${2:-}"
  local IFS=$' \t\n'

  bashunit::runner::order_functions_for_script "$script" "$fns"

  local wants_json=false
  if [ "$BASHUNIT_LIST_FORMAT" = "json" ]; then
    wants_json=true
    # Tags are only needed for the JSON columns; building the map per file is
    # one awk scan, so skip it entirely for text output.
    bashunit::helper::build_tags_map "$script"
  fi

  local fn
  for fn in $_BASHUNIT_RUNNER_ORDERED_FNS_OUT; do
    [ -z "$fn" ] && continue
    _BASHUNIT_LIST_COUNT=$((_BASHUNIT_LIST_COUNT + 1))

    if [ "$wants_json" = false ]; then
      printf '%s::%s\n' "$script" "$fn"
      continue
    fi

    local name line tags tags_json tag
    name=$(bashunit::helper::normalize_test_function_name "$fn")
    line=$(bashunit::helper::get_function_line_number "$fn")
    bashunit::helper::tags_for_function "$fn"
    tags="$_BASHUNIT_TAGS_OUT"

    tags_json=""
    # Tags are comma-separated because a tag may contain spaces (`# @tag needs a
    # db`), the same split every other consumer uses (src/helper/tags.sh:137).
    # IFS is restored right after the split: the helpers called below run under
    # the caller's dynamic scope and must not see a comma-only IFS.
    local old_ifs="$IFS"
    IFS=','
    local -a tag_list=()
    for tag in $tags; do
      tag_list[${#tag_list[@]}]="$tag"
    done
    IFS="$old_ifs"

    for tag in ${tag_list[@]+"${tag_list[@]}"}; do
      [ -z "$tag" ] && continue
      [ -n "$tags_json" ] && tags_json="$tags_json,"
      tags_json="$tags_json\"$(bashunit::reports::__json_escape "$tag")\""
    done

    local item
    item="{\"file\":\"$(bashunit::reports::__json_escape "$script")\""
    item="$item,\"function\":\"$(bashunit::reports::__json_escape "$fn")\""
    item="$item,\"name\":\"$(bashunit::reports::__json_escape "$name")\""
    item="$item,\"line\":${line:-0}"
    item="$item,\"tags\":[$tags_json]}"

    [ -n "$_BASHUNIT_LIST_JSON_ITEMS" ] && _BASHUNIT_LIST_JSON_ITEMS="$_BASHUNIT_LIST_JSON_ITEMS,"
    _BASHUNIT_LIST_JSON_ITEMS="$_BASHUNIT_LIST_JSON_ITEMS$item"
  done
}

##
# Closes the listing: the JSON document, or the count on stderr so that stdout
# stays a clean list of ids for piping.
##
function bashunit::runner::list_render_summary() {
  if [ "$BASHUNIT_LIST_FORMAT" = "json" ]; then
    printf '{"count":%s,"tests":[%s]}\n' \
      "$_BASHUNIT_LIST_COUNT" "$_BASHUNIT_LIST_JSON_ITEMS"
    return 0
  fi

  local unit="tests"
  [ "$_BASHUNIT_LIST_COUNT" -eq 1 ] && unit="test"
  printf '%s %s\n' "$_BASHUNIT_LIST_COUNT" "$unit" >&2
}
