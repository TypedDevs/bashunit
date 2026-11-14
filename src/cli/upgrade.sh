#!/usr/bin/env bash

function bashunit::upgrade::upgrade() {
  local install_dir="${BASHUNIT_INSTALL_DIR:-}"
  if [ -z "$install_dir" ]; then
    install_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  local target="$install_dir/bashunit"
  if [ -d "$target" ]; then
    echo "Failed to upgrade: $target is not a file" >&2
    return 1
  fi

  local latest_tag
  latest_tag="$(bashunit::helper::get_latest_tag)"

  if [ -z "$latest_tag" ]; then
    echo "Failed to resolve latest bashunit version. Check your internet connection and that 'git' is installed." >&2
    return 1
  fi

  if [ "$BASHUNIT_VERSION" = "$latest_tag" ]; then
    echo "> You are already on latest version"
    return 0
  fi

  echo "> Upgrading bashunit to latest version"

  local url="https://github.com/TypedDevs/bashunit/releases/download/$latest_tag/bashunit"
  local download_file
  if ! download_file=$("$MKTEMP" "$target.download.XXXXXX"); then
    echo "Failed to create a download file next to $target" >&2
    return 1
  fi
  if [ -f "$target" ]; then
    if ! cp -p "$target" "$download_file" || ! : >"$download_file"; then
      echo "Failed to prepare a download file next to $target" >&2
      rm -f "$download_file"
      return 1
    fi
  elif ! chmod +rw "$download_file"; then
    rm -f "$download_file"
    return 1
  fi
  local err_file
  err_file="$(mktemp 2>/dev/null || echo "/tmp/bashunit_upgrade_err.$$")"
  local download_status=0
  bashunit::io::download_to "$url" "$download_file" 2>"$err_file" || download_status=$?

  if [ "$download_status" -ne 0 ]; then
    echo "Failed to download bashunit $latest_tag from $url" >&2
    if [ -s "$err_file" ]; then
      echo "Reason:" >&2
      sed 's/^/  /' "$err_file" >&2
    fi
    rm -f "$err_file" "$download_file"
    return 1
  fi
  rm -f "$err_file"

  if [ ! -s "$download_file" ]; then
    echo "Failed to download bashunit $latest_tag from $url (empty file)" >&2
    rm -f "$download_file"
    return 1
  fi

  if ! bashunit::upgrade::verify_checksum "$url" "$download_file" "$latest_tag"; then
    rm -f "$download_file"
    return 1
  fi

  if ! chmod u+x "$download_file"; then
    echo "Failed to make $download_file executable" >&2
    rm -f "$download_file"
    return 1
  fi
  if ! mv -f "$download_file" "$target"; then
    echo "Failed to replace $target" >&2
    rm -f "$download_file"
    return 1
  fi

  echo "> bashunit upgraded successfully to latest version $latest_tag"
}

function bashunit::upgrade::sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  fi
}

##
# Same rules as install.sh: BASHUNIT_VERIFY_CHECKSUM unset verifies and only
# warns when verification is impossible, `true` also fails then, `false` skips.
##
function bashunit::upgrade::cannot_verify() {
  if [ "${BASHUNIT_VERIFY_CHECKSUM:-}" = "true" ]; then
    echo "Failed to verify the download: $1" >&2
    return 1
  fi
  echo "> Skipping checksum verification: $1" >&2
}

function bashunit::upgrade::verify_checksum() {
  local url=$1 download_file=$2 tag=$3
  if [ "${BASHUNIT_VERIFY_CHECKSUM:-}" = "false" ]; then
    return 0
  fi

  local actual
  actual=$(bashunit::upgrade::sha256 "$download_file")
  if [ -z "$actual" ]; then
    bashunit::upgrade::cannot_verify "no sha256 tool (shasum or sha256sum) is available"
    return
  fi

  local checksum_url="${url%/bashunit}/checksum"
  local checksum_file expected="" rest
  if ! checksum_file=$("$MKTEMP" "${download_file}.checksum.XXXXXX"); then
    bashunit::upgrade::cannot_verify "could not create a file for the checksum"
    return
  fi
  if bashunit::io::download_to "$checksum_url" "$checksum_file" 2>/dev/null; then
    read -r expected rest <"$checksum_file" || true
  fi
  rm -f "$checksum_file"

  if [ -z "$expected" ]; then
    bashunit::upgrade::cannot_verify "could not download the checksum from $checksum_url"
    return
  fi

  if [ "$actual" != "$expected" ]; then
    echo "Failed to upgrade: checksum mismatch for bashunit $tag" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi

  echo "> Checksum verified ($actual)"
}
