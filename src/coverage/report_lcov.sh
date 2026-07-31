#!/usr/bin/env bash

# LCOV coverage report.

function bashunit::coverage::report_lcov() {
  local output_file="${1:-$BASHUNIT_COVERAGE_REPORT}"

  if [ -z "$output_file" ]; then
    return 0
  fi

  # Create output directory if needed
  mkdir -p "$(dirname "$output_file")"

  # Generate LCOV format
  {
    echo "TN:"

    while IFS= read -r file; do
      { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

      echo "SF:$file"

      bashunit::coverage::load_hits_by_line "$file"

      # Function records (FN/FNDA/FNF/FNH). Emit FN lines as we walk
      # and buffer the matching FNDA lines for emission after, per
      # LCOV convention.
      local fn_total=0 fn_hit=0 fn_name fn_start fn_end fln any_hit
      local -a fn_dn_records=()
      local _fdi=0
      while IFS='|' read -r fn_name fn_start fn_end; do
        [ -z "$fn_name" ] && continue
        echo "FN:${fn_start},${fn_name}"
        fn_total=$((fn_total + 1))

        any_hit=0
        for ((fln = fn_start; fln <= fn_end; fln++)); do
          if [ "${_BASHUNIT_COVERAGE_HITS_BY_LINE[$fln]:-0}" -gt 0 ]; then
            any_hit=1
            break
          fi
        done
        fn_dn_records[_fdi]="FNDA:${any_hit},${fn_name}"
        _fdi=$((_fdi + 1))
        [ "$any_hit" -eq 1 ] && fn_hit=$((fn_hit + 1))
      done < <(bashunit::coverage::extract_functions "$file")

      local fda
      for fda in ${fn_dn_records[@]+"${fn_dn_records[@]}"}; do
        echo "$fda"
      done
      echo "FNF:$fn_total"
      echo "FNH:$fn_hit"

      # Branch records (BRDA/BRF/BRH)
      local br_total=0 br_hit=0 br_line br_block br_idx br_taken
      while IFS='|' read -r br_line br_block br_idx br_taken; do
        [ -z "$br_line" ] && continue
        echo "BRDA:${br_line},${br_block},${br_idx},${br_taken}"
        br_total=$((br_total + 1))
        [ "$br_taken" -gt 0 ] && br_hit=$((br_hit + 1))
      done < <(bashunit::coverage::compute_branch_hits "$file")
      echo "BRF:$br_total"
      echo "BRH:$br_hit"

      local lineno=0 executable=0 hit=0 line line_hits
      local -a lcov_lines=()
      local _lli=0 _ll
      while IFS= read -r _ll || [ -n "$_ll" ]; do
        lcov_lines[_lli]="$_ll"
        ((++_lli))
      done <"$file"

      for line in "${lcov_lines[@]}"; do
        ((++lineno))
        bashunit::coverage::is_executable_line "$line" "$lineno" || continue
        ((++executable))
        local lh="${_BASHUNIT_COVERAGE_HITS_BY_LINE[$lineno]:-0}"
        [ "$lh" -gt 0 ] && ((++hit))
        echo "DA:${lineno},${lh}"
      done

      echo "LF:$executable"
      echo "LH:$hit"
      echo "end_of_record"
    done < <(bashunit::coverage::get_tracked_files)
  } >"$output_file"
}
