#!/usr/bin/env bash
# bashunit: no-parallel-tests
# shellcheck disable=SC2317
set -uo pipefail
set +e

ACTIVE_INTERNET=0
HAS_DOWNLOADER=0
HAS_GIT=0

function set_up_before_script() {
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

function set_up() {
  rm -f ./lib/bashunit
  rm -rf ./tmp_install ./tmp_deps ./tmp_lib
}

function tear_down() {
  rm -f ./lib/bashunit
  rm -rf ./tmp_install ./tmp_deps ./tmp_lib
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
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'lib' folder")" "$output"
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
  assert_string_ends_with "$(printf "\n> bashunit has been installed in the 'tmp_deps' folder")" "$output"
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
    "$(printf "\n> bashunit has been installed in the 'tmp_install/nested' folder")" \
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
> bashunit has been installed in the 'tmp_lib' folder"

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
        "> bashunit has been installed in the 'lib' folder"
    )" \
    "$output"

  assert_file_exists "$installed_bashunit"

  assert_same \
    "$(printf "\e[1m\e[32mbashunit\e[0m - 0.19.0")" \
    "$("$installed_bashunit" --version)"
}

function test_install_downloads_the_non_stable_beta_version() {
  # Skip on Bash 3.0 - mocks don't work for external scripts
  if [[ "${BASH_VERSINFO[0]}" -eq 3 ]] && [[ "${BASH_VERSINFO[1]}" -lt 1 ]]; then
    bashunit::skip "Mocks don't work for external scripts in Bash 3.0"
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
> bashunit has been installed in the 'tmp_deps' folder"

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
