#!/usr/bin/env bash
set -euo pipefail

# Script that automates the release steps described in .github/RELEASE.md
# Usage: ./release.sh [--dry-run] <new-version>

IS_DRY_RUN=0

if [ "${1:-}" = "--dry-run" ]; then
  IS_DRY_RUN=1
  shift
fi

if [ $# -ne 1 ]; then
  echo "Usage: $0 [--dry-run] <new-version>" >&2
  exit 1
fi

NEW_VERSION="$1"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

OLD_VERSION="$(grep -o 'BASHUNIT_VERSION="[^\"]*' bashunit | sed 's/BASHUNIT_VERSION="//')"

if [ -z "$OLD_VERSION" ]; then
  echo "Could not determine OLD_VERSION" >&2
  exit 1
fi

# Update versions across the repository
sed -i.bak "s/declare -r BASHUNIT_VERSION=\"${OLD_VERSION}\"/declare -r BASHUNIT_VERSION=\"${NEW_VERSION}\"/" bashunit && rm bashunit.bak
sed -i.bak "s/LATEST_BASHUNIT_VERSION=\"${OLD_VERSION}\"/LATEST_BASHUNIT_VERSION=\"${NEW_VERSION}\"/" install.sh && rm install.sh.bak
sed -i.bak "s/\"version\": \"${OLD_VERSION}\"/\"version\": \"${NEW_VERSION}\"/" package.json && rm package.json.bak

DATE="$(date +%Y-%m-%d)"
NEW_CHANGELOG_HEADER="## [${NEW_VERSION}](https://github.com/TypedDevs/bashunit/compare/${OLD_VERSION}...${NEW_VERSION}) - ${DATE}"

# Update CHANGELOG
sed -i.bak "0,/^## Unreleased/s//${NEW_CHANGELOG_HEADER//\//\/}/" CHANGELOG.md && rm CHANGELOG.md.bak
sed -i.bak '3i\
## Unreleased\
' CHANGELOG.md && rm CHANGELOG.md.bak

# Build and checksum
./build.sh bin
CHECKSUM="$(awk '{print $1}' bin/checksum)"
sed -i.bak "s/\"checksum\": \"[a-f0-9]*\"/\"checksum\": \"${CHECKSUM}\"/" package.json && rm package.json.bak

# Commit and tag
if [ "$IS_DRY_RUN" -eq 1 ]; then
  echo "Would run: git add bashunit install.sh CHANGELOG.md package.json"
  echo "Would run: git commit -m 'release: ${NEW_VERSION}'"
  echo "Would run: git tag -a '${NEW_VERSION}' -m 'Release ${NEW_VERSION}'"
else
  git add bashunit install.sh CHANGELOG.md package.json
  git commit -m "release: ${NEW_VERSION}"
  git tag -a "${NEW_VERSION}" -m "Release ${NEW_VERSION}"
fi

# Generate release notes
RELEASE_NOTES="$(gh pr list \
  --search "merged:>=${DATE}" \
  --state merged \
  --json title,number,labels \
  --limit 100 | jq -r '
    def safe_labels: (.labels // [] | map(.name));
    def match_label($pattern): safe_labels | map(test($pattern)) | any;

    def section($heading; $pattern):
      [.[] | select(match_label($pattern))] as $prs |
      if ($prs | length) > 0 then
        "## \($heading)\n\n" +
        ($prs | map("- \(.title) [#\(.number)](https://github.com/TypedDevs/bashunit/pull/\(.number))") | join("\n"))
      else "" end;

    [
      section("✌️ New Features"; "^(feature|enhancement|feat)$"),
      section("🐛 Bug Fixes"; "^(bug|fix)$"),
      section("📚 Miscellaneous"; "^(chore|docs?|misc)$")
    ] | map(select(length > 0)) | join("\n\n")
  ')"

# Create GitHub release
if [ "$IS_DRY_RUN" -eq 1 ]; then
  echo "Would run: gh release create ${NEW_VERSION} bin/bashunit bin/checksum -t ${NEW_VERSION} -n <RELEASE_NOTES>"
else
  gh release create "${NEW_VERSION}" bin/bashunit bin/checksum -t "${NEW_VERSION}" -n "$RELEASE_NOTES"
fi

# Push and update latest branch
if git rev-parse --verify origin >/dev/null 2>&1; then
  if [ "$IS_DRY_RUN" -eq 1 ]; then
    echo "Would run: git push origin HEAD"
    echo "Would run: git push origin ${NEW_VERSION}"
    echo "Would run: git branch -f latest ${NEW_VERSION}"
    echo "Would run: git push origin latest --force"
  else
    git push origin HEAD
    git push origin "${NEW_VERSION}"
    git branch -f latest "${NEW_VERSION}"
    git push origin latest --force
  fi
fi
