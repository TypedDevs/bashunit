#!/usr/bin/env bash
# shellcheck disable=SC2317

_XMLLINT_AVAILABLE=false
if command -v xmllint >/dev/null 2>&1; then
  _XMLLINT_AVAILABLE=true
fi

_COBERTURA_DTD="tests/unit/coverage/fixtures/coverage-04.dtd"

_ORIG_COVERAGE_DATA_FILE=""
_ORIG_COVERAGE_TRACKED_FILES=""
_ORIG_COVERAGE_TRACKED_CACHE_FILE=""
_ORIG_COVERAGE=""

function set_up() {
  _ORIG_COVERAGE_DATA_FILE="$_BASHUNIT_COVERAGE_DATA_FILE"
  _ORIG_COVERAGE_TRACKED_FILES="$_BASHUNIT_COVERAGE_TRACKED_FILES"
  _ORIG_COVERAGE_TRACKED_CACHE_FILE="$_BASHUNIT_COVERAGE_TRACKED_CACHE_FILE"
  _ORIG_COVERAGE="${BASHUNIT_COVERAGE:-}"

  _BASHUNIT_COVERAGE_DATA_FILE=""
  _BASHUNIT_COVERAGE_TRACKED_FILES=""
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE=""
  export BASHUNIT_COVERAGE="true"
  bashunit::coverage::init
}

function tear_down() {
  if [ -n "$_BASHUNIT_COVERAGE_DATA_FILE" ] &&
    [ "$_BASHUNIT_COVERAGE_DATA_FILE" != "$_ORIG_COVERAGE_DATA_FILE" ]; then
    local coverage_dir
    coverage_dir=$(dirname "$_BASHUNIT_COVERAGE_DATA_FILE")
    rm -rf "$coverage_dir" 2>/dev/null || true
  fi

  _BASHUNIT_COVERAGE_DATA_FILE="$_ORIG_COVERAGE_DATA_FILE"
  _BASHUNIT_COVERAGE_TRACKED_FILES="$_ORIG_COVERAGE_TRACKED_FILES"
  _BASHUNIT_COVERAGE_TRACKED_CACHE_FILE="$_ORIG_COVERAGE_TRACKED_CACHE_FILE"
  if [ -n "$_ORIG_COVERAGE" ]; then
    export BASHUNIT_COVERAGE="$_ORIG_COVERAGE"
  else
    unset BASHUNIT_COVERAGE
  fi
}

# Two executable lines, one hit: line-rate 0.50 at every level.
function _cobertura_half_covered_fixture() {
  local temp_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 2"
echo "line 3"
EOF
  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  echo "$temp_file"
}

function test_cobertura_root_attributes_and_structure() {
  local temp_file report_file
  temp_file=$(_cobertura_half_covered_fixture)
  report_file=$(mktemp)

  bashunit::coverage::report_cobertura "$report_file"

  local content
  content=$(cat "$report_file")
  assert_contains '<?xml version="1.0"?>' "$content"
  assert_contains 'line-rate="0.50"' "$content"
  assert_contains 'lines-covered="1" lines-valid="2"' "$content"
  assert_contains '<sources>' "$content"
  assert_contains "<source>$PWD</source>" "$content"
  assert_contains '<packages>' "$content"
  assert_contains '<methods/>' "$content"
  assert_matches 'timestamp="[0-9]+"' "$content"

  rm -f "$temp_file" "$report_file"
}

function test_cobertura_lines_carry_number_and_hits() {
  local temp_file report_file
  temp_file=$(_cobertura_half_covered_fixture)
  report_file=$(mktemp)

  bashunit::coverage::report_cobertura "$report_file"

  local content
  content=$(cat "$report_file")
  assert_contains '<line number="2" hits="1" branch="false"/>' "$content"
  assert_contains '<line number="3" hits="0" branch="false"/>' "$content"

  rm -f "$temp_file" "$report_file"
}

function test_cobertura_filename_is_repo_relative() {
  # A tracked file under $PWD must be reported relative to it: GitLab resolves
  # filenames against the repository root and silently shows nothing when they
  # are absolute.
  local scratch_dir temp_file report_file
  scratch_dir=$(mktemp -d "$PWD/.cobertura_fixture.XXXXXX")
  temp_file="$scratch_dir/covered.sh"
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "line 2"
EOF
  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  echo "${temp_file}:2" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  report_file=$(mktemp)

  bashunit::coverage::report_cobertura "$report_file"

  local content
  content=$(cat "$report_file")
  assert_contains "filename=\"${scratch_dir##*/}/covered.sh\"" "$content"
  assert_not_contains "filename=\"$PWD" "$content"
  assert_contains 'name="covered.sh"' "$content"

  rm -f "$report_file"
  # Guarded recursive delete: only ever a .cobertura_fixture.* dir under $PWD.
  case "$scratch_dir" in
    "$PWD"/.cobertura_fixture.*) rm -rf "$scratch_dir" ;;
  esac
}

function test_cobertura_branch_lines_carry_condition_coverage() {
  local temp_file report_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "yes" ]; then
  echo "then"
else
  echo "else"
fi
EOF
  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  # The decision line and the then-arm ran; the else-arm never did.
  printf '%s:2\n%s:3\n' "$temp_file" "$temp_file" >>"$_BASHUNIT_COVERAGE_DATA_FILE"
  report_file=$(mktemp)

  bashunit::coverage::report_cobertura "$report_file"

  local content
  content=$(cat "$report_file")
  assert_contains 'branch="true"' "$content"
  assert_contains 'condition-coverage="50% (1/2)"' "$content"

  rm -f "$temp_file" "$report_file"
}

function test_cobertura_zero_hit_file_still_appears() {
  local temp_file report_file
  temp_file=$(mktemp)
  cat >"$temp_file" <<'EOF'
#!/usr/bin/env bash
echo "never runs"
EOF
  echo "$temp_file" >"$_BASHUNIT_COVERAGE_TRACKED_FILES"
  report_file=$(mktemp)

  bashunit::coverage::report_cobertura "$report_file"

  local content
  content=$(cat "$report_file")
  assert_contains "name=\"${temp_file##*/}\"" "$content"
  assert_contains 'line-rate="0.00"' "$content"

  rm -f "$temp_file" "$report_file"
}

function test_cobertura_validates_against_the_dtd() {
  if [ "$_XMLLINT_AVAILABLE" = false ]; then bashunit::skip "xmllint required"; return; fi
  local temp_file report_file
  temp_file=$(_cobertura_half_covered_fixture)
  report_file=$(mktemp)

  bashunit::coverage::report_cobertura "$report_file"

  assert_successful_code "$(xmllint --noout --dtdvalid "$_COBERTURA_DTD" "$report_file" 2>&1)"

  rm -f "$temp_file" "$report_file"
}
