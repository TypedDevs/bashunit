#!/usr/bin/env bash

# Cobertura XML coverage report (coverage-04.dtd). LCOV feeds Codecov and
# Coveralls; Cobertura is what the CI platforms with built-in coverage UIs
# consume: GitLab MR visualisation, Azure PublishCodeCoverageResults and the
# Jenkins Coverage plugin.

# Turns hit/total counts into a "0.87"-style rate, written into the slot
# below. Derived from the same integer percentage the console report prints,
# so the two can never disagree; the literal dot keeps it locale-immune.
_BASHUNIT_COBERTURA_RATE_OUT=""
function bashunit::coverage::__cobertura_rate() {
  local hit="$1"
  local total="$2"
  local pct=0
  if [ "$total" -gt 0 ]; then
    pct=$((hit * 100 / total))
  fi
  _BASHUNIT_COBERTURA_RATE_OUT="$((pct / 100)).$(printf '%02d' "$((pct % 100))")"
}

function bashunit::coverage::report_cobertura() {
  local output_file="${1:-$BASHUNIT_COVERAGE_REPORT_COBERTURA}"

  if [ -z "$output_file" ]; then
    return 0
  fi

  mkdir -p "$(dirname "$output_file")"

  local timestamp
  timestamp=$(date +%s)

  # Package accumulators, grouped by the dotted directory of the repo-relative
  # path. Parallel indexed arrays instead of declare -A (Bash 3.0): the lookup
  # is a linear scan over the package count, which is small.
  local pkg_names pkg_exec pkg_hit pkg_br_total pkg_br_taken pkg_classes
  pkg_names=()
  pkg_exec=()
  pkg_hit=()
  pkg_br_total=()
  pkg_br_taken=()
  pkg_classes=()

  local total_exec=0 total_hit=0 total_br=0 total_br_taken=0

  local file
  while IFS= read -r file; do
    { [ -z "$file" ] || [ ! -f "$file" ]; } && continue

    # GitLab resolves filenames against the repository root and silently shows
    # nothing for absolute paths, so anything under $PWD is made relative.
    local rel="${file#"$PWD"/}"
    local class_name="${rel##*/}"
    local pkg_name
    case "$rel" in
      */*) pkg_name="${rel%/*}" ;;
      *) pkg_name="." ;;
    esac
    pkg_name="${pkg_name//\//.}"

    bashunit::coverage::load_hits_by_line "$file"

    # Branch arms per decision line, keyed by the (numeric) line itself.
    local -a br_arms=()
    local -a br_arms_taken=()
    local br_line br_block br_idx br_taken
    local file_br=0 file_br_taken=0
    # shellcheck disable=SC2034 # block/idx are LCOV fields this format ignores
    while IFS='|' read -r br_line br_block br_idx br_taken; do
      [ -z "$br_line" ] && continue
      br_arms[br_line]=$((${br_arms[br_line]:-0} + 1))
      file_br=$((file_br + 1))
      if [ "$br_taken" -gt 0 ]; then
        br_arms_taken[br_line]=$((${br_arms_taken[br_line]:-0} + 1))
        file_br_taken=$((file_br_taken + 1))
      fi
    done < <(bashunit::coverage::compute_branch_hits "$file")

    local -a src_lines=()
    local _sli=0 _sl
    while IFS= read -r _sl || [ -n "$_sl" ]; do
      src_lines[_sli]="$_sl"
      _sli=$((_sli + 1))
    done <"$file"

    local lines_xml="" lineno=0 file_exec=0 file_hit=0 line
    for line in ${src_lines[@]+"${src_lines[@]}"}; do
      lineno=$((lineno + 1))
      bashunit::coverage::is_executable_line "$line" "$lineno" || continue
      file_exec=$((file_exec + 1))
      local lh="${_BASHUNIT_COVERAGE_HITS_BY_LINE[$lineno]:-0}"
      [ "$lh" -gt 0 ] && file_hit=$((file_hit + 1))

      local arms="${br_arms[$lineno]:-0}"
      if [ "$arms" -gt 0 ]; then
        local taken="${br_arms_taken[$lineno]:-0}"
        local cond_pct=$((taken * 100 / arms))
        lines_xml="$lines_xml          <line number=\"$lineno\" hits=\"$lh\" branch=\"true\" \
condition-coverage=\"${cond_pct}% (${taken}/${arms})\"/>
"
      else
        lines_xml="$lines_xml          <line number=\"$lineno\" hits=\"$lh\" branch=\"false\"/>
"
      fi
    done

    total_exec=$((total_exec + file_exec))
    total_hit=$((total_hit + file_hit))
    total_br=$((total_br + file_br))
    total_br_taken=$((total_br_taken + file_br_taken))

    local p=-1 j
    for j in ${pkg_names[@]+"${!pkg_names[@]}"}; do
      if [ "${pkg_names[$j]}" = "$pkg_name" ]; then
        p=$j
        break
      fi
    done
    if [ "$p" -eq -1 ]; then
      p=${#pkg_names[@]}
      pkg_names[p]="$pkg_name"
      pkg_exec[p]=0
      pkg_hit[p]=0
      pkg_br_total[p]=0
      pkg_br_taken[p]=0
      pkg_classes[p]=""
    fi
    pkg_exec[p]=$((pkg_exec[p] + file_exec))
    pkg_hit[p]=$((pkg_hit[p] + file_hit))
    pkg_br_total[p]=$((pkg_br_total[p] + file_br))
    pkg_br_taken[p]=$((pkg_br_taken[p] + file_br_taken))

    local class_line_rate class_branch_rate
    bashunit::coverage::__cobertura_rate "$file_hit" "$file_exec"
    class_line_rate=$_BASHUNIT_COBERTURA_RATE_OUT
    bashunit::coverage::__cobertura_rate "$file_br_taken" "$file_br"
    class_branch_rate=$_BASHUNIT_COBERTURA_RATE_OUT

    pkg_classes[p]="${pkg_classes[p]}        <class name=\"$class_name\" filename=\"$rel\" \
line-rate=\"$class_line_rate\" branch-rate=\"$class_branch_rate\" complexity=\"0.0\">
          <methods/>
          <lines>
$lines_xml          </lines>
        </class>
"
  done < <(bashunit::coverage::get_tracked_files)

  local line_rate branch_rate
  bashunit::coverage::__cobertura_rate "$total_hit" "$total_exec"
  line_rate=$_BASHUNIT_COBERTURA_RATE_OUT
  bashunit::coverage::__cobertura_rate "$total_br_taken" "$total_br"
  branch_rate=$_BASHUNIT_COBERTURA_RATE_OUT

  {
    echo '<?xml version="1.0"?>'
    echo "<coverage line-rate=\"$line_rate\" branch-rate=\"$branch_rate\"" \
      "lines-covered=\"$total_hit\" lines-valid=\"$total_exec\"" \
      "branches-covered=\"$total_br_taken\" branches-valid=\"$total_br\"" \
      "complexity=\"0.0\" version=\"${BASHUNIT_VERSION:-0}\" timestamp=\"$timestamp\">"
    echo "  <sources>"
    echo "    <source>$PWD</source>"
    echo "  </sources>"
    echo "  <packages>"

    local s
    for s in ${pkg_names[@]+"${!pkg_names[@]}"}; do
      local pkg_line_rate pkg_branch_rate
      bashunit::coverage::__cobertura_rate "${pkg_hit[$s]}" "${pkg_exec[$s]}"
      pkg_line_rate=$_BASHUNIT_COBERTURA_RATE_OUT
      bashunit::coverage::__cobertura_rate "${pkg_br_taken[$s]}" "${pkg_br_total[$s]}"
      pkg_branch_rate=$_BASHUNIT_COBERTURA_RATE_OUT
      echo "    <package name=\"${pkg_names[$s]}\" line-rate=\"$pkg_line_rate\"" \
        "branch-rate=\"$pkg_branch_rate\" complexity=\"0.0\">"
      echo "      <classes>"
      printf '%s' "${pkg_classes[$s]}"
      echo "      </classes>"
      echo "    </package>"
    done

    echo "  </packages>"
    echo "</coverage>"
  } >"$output_file"
}
