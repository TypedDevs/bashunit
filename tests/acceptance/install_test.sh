#!/usr/bin/env bash
# bashunit: no-parallel-tests
# shellcheck disable=SC2317
set -uo pipefail
set +e

ACTIVE_INTERNET=0
HAS_DOWNLOADER=0
HAS_GIT=0

function set_up_before_script() {
  INSTALL_ROOT_DIR="$(pwd)"
  if bashunit::env::active_internet_connection; then
    ACTIVE_INTERNET=0
  else
    ACTIVE_INTERNET=1
  fi
  if bashunit::dependencies::has_curl || bashunit::dependencies::has_wget; then
    HAS_DOWNLOADER=1
  fi
  if bashunit::dependencies::has_git; then
    HAS_GIT=1
  fi
}

function tear_down_after_script() {
  set -e
}

# Each install runs in an isolated caller directory to avoid shared outputs.
function set_up() {
  SANDBOX="$(bashunit::temp_dir)"
  cp "$INSTALL_ROOT_DIR/install.sh" "$SANDBOX/install.sh"
  cd "$SANDBOX" || return 1
  SANDBOX="$(pwd)"
}

function provide_caller_directory_install_modes() {
  bashunit::data_set saved
  bashunit::data_set piped
  bashunit::data_set absolute
}

# @data_provider provide_caller_directory_install_modes
function test_install_uses_the_callers_directory() {
  local mode="$1" project="$SANDBOX/project" elsewhere="$SANDBOX/script" shims="$SANDBOX/shims"
  mkdir -p "$project" "$elsewhere" "$shims"
  cp ./install.sh "$elsewhere/install.sh"
  cat >"$shims/curl" <<'SH'
#!/usr/bin/env bash
target=bashunit
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) target=$2; shift ;;
  esac
  shift
done
printf '#!/usr/bin/env bash\necho offline\n' >"$target"
SH
  chmod +x "$shims/curl"

  local destination=lib expected="$project/lib"
  if [ "$mode" = absolute ]; then
    destination="$project/absolute"
    expected="$destination"
  fi
  local status=0 output
  output=$(
    cd "$project" || exit 1
    if [ "$mode" = piped ]; then
      cat "$elsewhere/install.sh" | PATH="$shims:$PATH" BASHUNIT_VERIFY_CHECKSUM=false \
        bash -s -- "$destination" 0.52.0
    else
      PATH="$shims:$PATH" BASHUNIT_VERIFY_CHECKSUM=false \
        bash "$elsewhere/install.sh" "$destination" 0.52.0
    fi
  ) || status=$?

  assert_successful_code "" "" "$status"
  assert_file_exists "$expected/bashunit"
  assert_same offline "$("$expected/bashunit")"
  assert_contains "installed in the '$expected' folder" "$output"
  assert_directory_not_exists "$elsewhere/lib"
}

function test_install_downloads_the_latest_version() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./lib/bashunit"
  local output

  output="$(./install.sh)"

  if [ ! -f "$installed_bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the '%s' folder" "$SANDBOX/lib")" "$output"
  assert_file_exists "$installed_bashunit"

  # Guard: skip version check if binary is non-functional after download (network flake)
  local version
  version="$("$installed_bashunit" --version 2>/dev/null)"
  if [[ -z "$version" ]]; then
    bashunit::skip "binary non-functional after install (transient network failure)" && return
  fi
  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" "$version"
}

function test_install_downloads_in_given_folder() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./tmp_deps/bashunit"
  local output

  output="$(./install.sh tmp_deps)"

  if [ ! -f "$installed_bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  assert_string_starts_with "$(printf "> Downloading the latest version: '")" "$output"
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the '%s' folder" "$SANDBOX/tmp_deps")" "$output"
  assert_file_exists "$installed_bashunit"

  # Guard: skip version check if binary is non-functional after download (network flake)
  local version
  version="$("$installed_bashunit" --version 2>/dev/null)"
  if [[ -z "$version" ]]; then
    bashunit::skip "binary non-functional after install (transient network failure)" && return
  fi
  assert_string_starts_with "$(printf "\e[1m\e[32mbashunit\e[0m - ")" "$version"
}

function test_install_downloads_in_nested_folder() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./tmp_install/nested/bashunit"
  local output

  output="$(./install.sh tmp_install/nested)"

  if [ ! -f "$installed_bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  assert_string_ends_with \
    "$(printf "\n> bashunit has been installed in the '%s' folder" "$SANDBOX/tmp_install/nested")" \
    "$output"
  assert_file_exists "$installed_bashunit"
}

function test_install_fails_loudly_on_unknown_version() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  assert_general_error "$(./install.sh tmp_install 99.99.99 2>&1)"
  assert_file_not_exists "./tmp_install/bashunit"
}

function provide_mistyped_install_versions() {
  bashunit::data_set v0.52.0
  bashunit::data_set lib v0.52.0
  bashunit::data_set v0.52.0 lib
  bashunit::data_set 0.52
  bashunit::data_set lib 0.52
  bashunit::data_set 0.52 lib
}

# @data_provider provide_mistyped_install_versions
function test_install_rejects_a_mistyped_version_before_downloading() {
  mkdir shims
  printf '#!/bin/sh\n: >"$INSTALL_DOWNLOAD_MARKER"\nexit 22\n' >shims/curl
  chmod +x shims/curl
  local invalid="$1" status=0 output
  if [ "$invalid" = lib ]; then
    invalid="$2"
  fi

  output=$(PATH="$SANDBOX/shims:$PATH" INSTALL_DOWNLOAD_MARKER="$SANDBOX/download.called" \
    ./install.sh "$@" 2>&1) || status=$?

  assert_general_error "" "" "$status"
  assert_contains "unknown version '$invalid'" "$output"
  assert_directory_not_exists "$SANDBOX/$invalid"
  assert_file_not_exists "$SANDBOX/download.called"
}

function provide_install_replacement_results() {
  bashunit::data_set failure
  bashunit::data_set empty
  bashunit::data_set mismatch
  bashunit::data_set success
}

# @data_provider provide_install_replacement_results
function test_install_replaces_the_previous_binary_only_after_a_valid_download() {
  local result="$1"
  mkdir -p shims destination
  printf 'previous binary\n' >destination/bashunit
  cat >shims/curl <<'SH'
#!/usr/bin/env bash
target=bashunit
checksum=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) target=$2; shift ;;
    */checksum) checksum=true ;;
  esac
  shift
done
if [ "$checksum" = true ]; then
  printf 'invalid-checksum\n'
  exit 0
fi
case "$INSTALL_TEST_DOWNLOAD_RESULT" in
  failure) printf 'partial download\n' >"$target"; exit 22 ;;
  empty) : >"$target" ;;
  *) printf '#!/bin/sh\nexit 0\n' >"$target" ;;
esac
SH
  chmod +x shims/curl
  local status=0 output verify=false
  if [ "$result" = mismatch ]; then
    verify=true
  fi
  output=$(
    umask 022
    PATH="$SANDBOX/shims:$PATH" INSTALL_TEST_DOWNLOAD_RESULT="$result" \
      BASHUNIT_VERIFY_CHECKSUM="$verify" ./install.sh destination 0.52.0 2>&1
  ) || status=$?

  if [ "$result" = success ]; then
    assert_successful_code "" "" "$status"
    assert_same "$(printf '#!/bin/sh\nexit 0')" "$(cat destination/bashunit)"
    assert_is_file_executable destination/bashunit
    if ! bashunit::check_os::is_windows; then
      assert_not_empty "$(find destination/bashunit -perm 0744 -print)"
    fi
  else
    assert_general_error "" "" "$status"
    assert_same 'previous binary' "$(cat destination/bashunit)"
    if [ "$result" = mismatch ]; then
      assert_contains 'checksum mismatch' "$output"
    else
      assert_contains 'failed to download' "$output"
    fi
  fi
  local leftover
  leftover=$(find destination -name 'bashunit.download.*' -print)
  assert_empty "$leftover"
}

function test_install_rejects_a_directory_at_the_binary_path() {
  mkdir -p destination/bashunit shims
  printf '#!/bin/sh\nexit 22\n' >shims/curl
  chmod +x shims/curl
  local status=0 output
  output=$(PATH="$SANDBOX/shims:$PATH" ./install.sh destination 0.52.0 2>&1) || status=$?

  assert_general_error "" "" "$status"
  assert_contains 'not a file' "$output"
  assert_empty "$(find destination/bashunit -type f -print)"
}

function test_install_verifies_checksum_when_enabled() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi
  if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
    bashunit::skip "no sha256 tool available" && return
  fi

  local output
  output="$(BASHUNIT_VERIFY_CHECKSUM=true ./install.sh tmp_install 0.37.0 2>&1)"

  if [ ! -f "./tmp_install/bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  case "$output" in
  *"Skipping checksum verification"*)
    bashunit::skip "checksum asset unreachable (transient network/env)" && return
    ;;
  esac
  assert_contains "Checksum verified" "$output"
  assert_file_exists "./tmp_install/bashunit"
  assert_same "$(printf "\e[1m\e[32mbashunit\e[0m - 0.37.0")" \
    "$(./tmp_install/bashunit --version)"
}

function test_install_verifies_checksum_by_default() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi
  if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
    bashunit::skip "no sha256 tool available" && return
  fi

  local output
  output="$(./install.sh tmp_install 0.38.0 2>&1)"

  if [ ! -f "./tmp_install/bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  case "$output" in
  *"Skipping checksum verification"*)
    bashunit::skip "checksum asset unreachable (transient network/env)" && return
    ;;
  esac
  assert_contains "Checksum verified" "$output"
  assert_file_exists "./tmp_install/bashunit"
}

function test_install_downloads_the_given_version() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./tmp_lib/bashunit"
  local output

  output="$(./install.sh tmp_lib 0.9.0)"

  if [ ! -f "$installed_bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  local expected
  expected="> Downloading a concrete version: '0.9.0'
> bashunit has been installed in the '$SANDBOX/tmp_lib' folder"

  assert_same "$expected" "$output"

  assert_file_exists "$installed_bashunit"

  assert_same "$(printf "\e[1m\e[32mbashunit\e[0m - 0.9.0")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_the_given_version_without_dir() {
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  local installed_bashunit="./lib/bashunit"
  local output
  output="$(./install.sh 0.19.0)"

  if [ ! -f "$installed_bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  assert_same \
    "$(
      printf "%s\n" \
        "> Downloading a concrete version: '0.19.0'" \
        "> bashunit has been installed in the '$SANDBOX/lib' folder"
    )" \
    "$output"

  assert_file_exists "$installed_bashunit"

  assert_same \
    "$(printf "\e[1m\e[32mbashunit\e[0m - 0.19.0")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_the_non_stable_beta_version() {
  # Skip on Bash 3.0 - mocks don't work for external scripts
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]]; then
    bashunit::skip "Mocks do not reach external scripts on Bash 3.x"
    return
  fi
  if [[ "$ACTIVE_INTERNET" -eq 1 ]]; then
    bashunit::skip "no internet connection" && return
  fi
  if [[ "$HAS_GIT" -eq 0 ]]; then
    bashunit::skip "git not installed" && return
  fi
  if [[ "$HAS_DOWNLOADER" -eq 0 ]]; then
    bashunit::skip "curl or wget not installed" && return
  fi

  bashunit::mock date <<<"2023-11-13"
  bashunit::mock tput <<<""
  local installed_bashunit="./tmp_deps/bashunit"
  local output

  output="$(./install.sh tmp_deps beta)"

  if [ ! -f "$installed_bashunit" ]; then
    bashunit::skip "transient download failure" && return
  fi
  local expected
  expected="> Downloading non-stable version: 'beta'
> bashunit has been installed in the '$SANDBOX/tmp_deps' folder"

  assert_contains "$expected" "$output"

  assert_file_exists "$installed_bashunit"

  assert_matches \
    "$(printf "\(non-stable\) beta after ([0-9]+\.[0-9]+\.[0-9]+) \[2023-11-13\] 🐍 \#[a-fA-F0-9]{7}")" \
    "$("$installed_bashunit" --version)"

  assert_directory_not_exists "./tmp_deps/temp_bashunit"

  file_count_of_tmp_deps_directory=$(find ./tmp_deps -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ')
  assert_same "$file_count_of_tmp_deps_directory" "1"
  assert_same "$(find ./tmp_deps -name 'bashunit')" "./tmp_deps/bashunit"
}

# Regression guard for #840: a failed `git clone` in the beta path must abort
# with a non-zero exit — it used to cascade (failed cd, build.sh executed in
# the caller's directory, missing copy) and still print the success message.
function test_install_beta_aborts_when_clone_fails() {
  local shim_dir
  shim_dir="$(bashunit::temp_dir)"
  printf '#!/usr/bin/env bash\nexit 128\n' >"$shim_dir/git"
  chmod +x "$shim_dir/git"

  local output
  local exit_code=0
  output="$(PATH="$shim_dir:$PATH" ./install.sh tmp_install beta 2>&1)" || exit_code=$?

  assert_not_equals 0 "$exit_code"
  assert_not_contains "has been installed" "$output"
  assert_file_not_exists "./tmp_install/bashunit"
  assert_directory_not_exists "./tmp_install/bin"
  assert_directory_not_exists "./tmp_install/temp_bashunit"
}

# The destination is validated before any network call, so these need no
# internet and no downloader. Both used to misdiagnose: an unwritable folder
# reported "failed to download ... from <url>", pointing at the network or the
# version, and a path that is a regular file leaked a raw `rm: Not a directory`
# that never mentioned bashunit (#1197).
function test_install_rejects_a_destination_that_is_a_regular_file() {
  local dir
  dir="$(bashunit::temp_dir)"
  cp ./install.sh "$dir/install.sh"
  printf 'not a dir\n' >"$dir/blocked"

  local ec=0
  local output
  output=$(cd "$dir" && ./install.sh 0.47.0 blocked 2>&1) || ec=$?

  assert_general_error "" "" "$ec"
  assert_contains "is not a directory" "$output"
}

# chmod is a no-op for root, and the Bash 3.0 job runs as root, so this asks
# the kernel rather than assuming: skip where the block would not hold.
function test_install_rejects_a_destination_it_cannot_write() {
  local dir
  dir="$(bashunit::temp_dir)"
  cp ./install.sh "$dir/install.sh"
  mkdir "$dir/ro" && chmod 555 "$dir/ro"
  if [ -w "$dir/ro" ]; then
    chmod 755 "$dir/ro"
    bashunit::skip "the current user can write to a 555 directory" && return
  fi

  local ec=0
  local output
  output=$(cd "$dir" && ./install.sh 0.47.0 ro 2>&1) || ec=$?
  chmod 755 "$dir/ro"

  assert_general_error "" "" "$ec"
  assert_contains "cannot write to" "$output"
}

# The three destination errors above all end with advice on how to recover, and
# the advice named a `-d` flag the script never had -- `install.sh` parses
# positional arguments only, so following it produced "Invalid arguments"
# (#1221). The assertions covered the diagnosis line and stopped there, which is
# exactly how an invented flag survives.
#
# So run the suggested form instead of string-matching it.
#
# Both runs stop before the network: the destination is validated first, and an
# unparseable argument is rejected before that. The retry therefore names a
# *second* blocked path rather than a usable one -- pointing it at a writable
# folder would parse, validate and then download the release, which cost this
# one test ~10s of the suite and made it fail without internet.
function test_the_recovery_advice_names_a_form_the_parser_accepts() {
  local dir
  dir="$(bashunit::temp_dir)"
  cp ./install.sh "$dir/install.sh"
  printf 'not a dir\n' >"$dir/blocked"
  printf 'not a dir either\n' >"$dir/elsewhere"

  local output
  output=$(cd "$dir" && ./install.sh 0.47.0 blocked 2>&1) || true
  assert_contains "Choose another destination" "$output"

  # The advice must not name a flag. Asserted against the run that actually
  # prints it: a flag-shaped argument dies in the parser before any of this,
  # so checking the advice there would compare against nothing at all.
  assert_not_contains "-d" "$output"

  # And what it does tell the reader to do -- pass a different destination as
  # an argument -- has to get past argument parsing. Reaching the destination
  # check at all is the proof: that is the stage after parsing.
  local retry
  retry=$(cd "$dir" && ./install.sh 0.47.0 elsewhere 2>&1) || true

  assert_not_contains "Invalid arguments" "$retry"
  assert_contains "Choose another destination" "$retry"
}

# The parser takes positional arguments only, which is what the advice above
# now describes.
function test_a_flag_shaped_destination_is_rejected() {
  local dir
  dir="$(bashunit::temp_dir)"
  cp ./install.sh "$dir/install.sh"

  local output
  output=$(cd "$dir" && ./install.sh -d somewhere 2>&1) || true

  assert_contains "Invalid arguments" "$output"
}
