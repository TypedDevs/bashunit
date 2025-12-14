#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

DRY_RUN=false
VERSION=""

function show_usage() {
  cat <<EOF
Usage: ./release.sh <version> [options]

Arguments:
  version     The new version number (e.g., 0.30.0)

Options:
  --dry-run   Preview changes without modifying any files
  -h, --help  Show this help message

Example:
  ./release.sh 0.30.0
  ./release.sh 0.30.0 --dry-run
EOF
}

function log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success() {
  echo -e "${GREEN}[OK]${NC} $1"
}

function log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

function log_dry_run() {
  echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

function validate_semver() {
  local version=$1
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $version"
    log_error "Version must be in semver format (e.g., 0.30.0)"
    exit 1
  fi
}

function get_current_version() {
  grep -o 'BASHUNIT_VERSION="[^"]*"' bashunit | cut -d'"' -f2
}

function version_gt() {
  # Returns 0 if $1 > $2
  local v1=$1
  local v2=$2

  if [[ "$v1" == "$v2" ]]; then
    return 1
  fi

  local IFS=.
  local i
  local ver1=($v1)
  local ver2=($v2)

  for ((i=0; i<3; i++)); do
    if ((ver1[i] > ver2[i])); then
      return 0
    elif ((ver1[i] < ver2[i])); then
      return 1
    fi
  done

  return 1
}

function update_bashunit_version() {
  local new_version=$1
  local file="bashunit"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would update BASHUNIT_VERSION in $file to $new_version"
    return
  fi

  sed -i.bak "s/BASHUNIT_VERSION=\"[^\"]*\"/BASHUNIT_VERSION=\"$new_version\"/" "$file"
  rm -f "$file.bak"
  log_success "Updated BASHUNIT_VERSION in $file"
}

function update_install_version() {
  local new_version=$1
  local file="install.sh"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would update LATEST_BASHUNIT_VERSION in $file to $new_version"
    return
  fi

  sed -i.bak "s/LATEST_BASHUNIT_VERSION=\"[^\"]*\"/LATEST_BASHUNIT_VERSION=\"$new_version\"/" "$file"
  rm -f "$file.bak"
  log_success "Updated LATEST_BASHUNIT_VERSION in $file"
}

function update_package_json_version() {
  local new_version=$1
  local file="package.json"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would update version in $file to $new_version"
    return
  fi

  sed -i.bak "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$file"
  rm -f "$file.bak"
  log_success "Updated version in $file"
}

function update_changelog() {
  local new_version=$1
  local current_version=$2
  local file="CHANGELOG.md"
  local today
  today=$(date +%Y-%m-%d)
  local compare_url="https://github.com/TypedDevs/bashunit/compare/${current_version}...${new_version}"

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would update $file:"
    log_dry_run "  - Add new '## Unreleased' section"
    log_dry_run "  - Convert current Unreleased to ## [$new_version]($compare_url) - $today"
    return
  fi

  # Create the new version header
  local new_header="## [$new_version]($compare_url) - $today"

  # Replace "## Unreleased" with new Unreleased + version header
  sed -i.bak "s/^## Unreleased$/## Unreleased\n\n$new_header/" "$file"
  rm -f "$file.bak"
  log_success "Updated $file with version $new_version"
}

function build_project() {
  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would run: ./build.sh bin"
    return
  fi

  log_info "Building project..."
  ./build.sh bin
  log_success "Build completed"
}

function get_checksum() {
  if [[ -f "bin/checksum" ]]; then
    awk '{print $1}' bin/checksum
  else
    echo ""
  fi
}

function get_contributors() {
  local prev_version=$1

  # Get GitHub handles of commit authors since previous version
  # Uses HEAD since the new version tag doesn't exist yet
  gh api "/repos/TypedDevs/bashunit/compare/${prev_version}...HEAD" \
    --jq '.commits[].author.login' 2>/dev/null | sort -u | grep -v '^$' || true
}

function generate_release_notes() {
  local new_version=$1
  local prev_version=$2
  local checksum=$3

  # Extract content between "## Unreleased" and next version header
  # Transform changelog sections to release format with emojis
  awk '/^## Unreleased$/{found=1; next} /^## \[/{found=0} found' CHANGELOG.md | \
    sed 's/^### Added$/## ✨ Improvements/' | \
    sed 's/^### Changed$/## 🛠️ Changes/' | \
    sed 's/^### Fixed$/## 🐛 Bug Fixes/' | \
    sed 's/^### Performance$/## ⚡ Performance/'

  # Add contributors section
  local contributors
  contributors=$(get_contributors "$prev_version")
  if [[ -n "$contributors" ]]; then
    echo ""
    echo "## 👥 Contributors"
    echo "$contributors" | while read -r user; do
      echo "- @$user"
    done
  fi

  # Append checksum and changelog link
  echo ""
  echo "## Checksum"
  echo "SHA256: \`$checksum\`"
  echo ""
  echo "**Full Changelog:** [$prev_version...$new_version](https://github.com/TypedDevs/bashunit/compare/$prev_version...$new_version)"
}

function create_github_release() {
  local version=$1
  local notes_file=$2

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would create GitHub release $version with assets:"
    log_dry_run "  - bin/bashunit"
    log_dry_run "  - bin/checksum"
    return
  fi

  if ! confirm_action "Do you want to create the GitHub release now?"; then
    log_warning "Skipping GitHub release creation"
    echo ""
    echo "To create the release manually, run:"
    echo -e "  ${BLUE}gh release create $version bin/bashunit bin/checksum --title \"$version\" --notes-file \"$notes_file\"${NC}"
    return
  fi

  log_info "Creating GitHub release..."
  gh release create "$version" \
    bin/bashunit \
    bin/checksum \
    --title "$version" \
    --notes-file "$notes_file"

  log_success "GitHub release $version created with assets"
}

function update_checksum() {
  local file="package.json"
  local checksum
  checksum=$(get_checksum)

  if [[ -z "$checksum" ]]; then
    log_error "Could not read checksum from bin/checksum"
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would update checksum in $file to $checksum"
    return
  fi

  sed -i.bak "s/\"checksum\": \"[^\"]*\"/\"checksum\": \"$checksum\"/" "$file"
  rm -f "$file.bak"
  log_success "Updated checksum in $file"
}

function show_diff() {
  echo ""
  log_info "Changes to be committed:"
  echo "----------------------------------------"
  git diff --color=always
  echo "----------------------------------------"
  echo ""
}

function confirm_action() {
  local prompt=$1
  local response

  echo -en "${YELLOW}$prompt [y/N]: ${NC}"
  read -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

function git_commit_and_tag() {
  local new_version=$1

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would create commit: chore: release $new_version"
    log_dry_run "Would create tag: $new_version"
    log_dry_run "Would push commit and tag to origin"
    return
  fi

  show_diff

  if ! confirm_action "Do you want to commit these changes?"; then
    log_warning "Skipping git commit"
    return
  fi

  git add bashunit install.sh package.json CHANGELOG.md bin/bashunit bin/checksum
  git commit -m "chore: release $new_version"
  log_success "Created commit"

  git tag "$new_version"
  log_success "Created tag $new_version"

  if confirm_action "Do you want to push commit and tag to origin?"; then
    git push origin main
    git push origin "$new_version"
    log_success "Pushed to origin"
  else
    log_warning "Skipping push (run manually: git push origin main && git push origin $new_version)"
  fi
}

function update_latest_branch() {
  local new_version=$1

  if [[ "$DRY_RUN" == true ]]; then
    log_dry_run "Would update 'latest' branch:"
    log_dry_run "  git checkout latest"
    log_dry_run "  git rebase $new_version"
    log_dry_run "  git push origin latest --force"
    log_dry_run "  git checkout main"
    return
  fi

  if ! confirm_action "Do you want to update 'latest' branch to trigger docs deployment?"; then
    log_warning "Skipping 'latest' branch update"
    echo ""
    echo "To update manually, run:"
    echo -e "  ${BLUE}git checkout latest && git rebase $new_version && git push origin latest --force && git checkout main${NC}"
    return
  fi

  log_info "Updating 'latest' branch..."
  git checkout latest
  git rebase "$new_version"
  git push origin latest --force
  git checkout main
  log_success "Updated 'latest' branch - docs deployment triggered"
}

function print_release_complete() {
  local new_version=$1

  echo ""
  echo "========================================"
  echo -e "${GREEN}Release $new_version complete!${NC}"
  echo "========================================"
  echo ""
}

#########################
######### MAIN ##########
#########################

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      if [[ -z "$VERSION" ]]; then
        VERSION=$1
      else
        log_error "Unknown argument: $1"
        show_usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Validate version argument
if [[ -z "$VERSION" ]]; then
  log_error "Version argument is required"
  show_usage
  exit 1
fi

validate_semver "$VERSION"

# Get current version
CURRENT_VERSION=$(get_current_version)
log_info "Current version: $CURRENT_VERSION"
log_info "New version: $VERSION"

# Validate new version is greater
if ! version_gt "$VERSION" "$CURRENT_VERSION"; then
  log_error "New version ($VERSION) must be greater than current version ($CURRENT_VERSION)"
  exit 1
fi

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  log_warning "DRY-RUN MODE - No files will be modified"
  echo ""
fi

# Execute release steps
log_info "Starting release process..."
echo ""

update_bashunit_version "$VERSION"
update_install_version "$VERSION"
update_package_json_version "$VERSION"
update_changelog "$VERSION" "$CURRENT_VERSION"

echo ""
build_project

echo ""
update_checksum

echo ""
git_commit_and_tag "$VERSION"

# Generate formatted release notes
RELEASE_NOTES_FILE="/tmp/bashunit-release-notes-${VERSION}.md"
CHECKSUM=$(get_checksum)

echo ""
if [[ "$DRY_RUN" == true ]]; then
  log_dry_run "Would save release notes to $RELEASE_NOTES_FILE"
  log_dry_run "Release notes content:"
  echo "----------------------------------------"
  generate_release_notes "$VERSION" "$CURRENT_VERSION" "$CHECKSUM"
  echo "----------------------------------------"
else
  generate_release_notes "$VERSION" "$CURRENT_VERSION" "$CHECKSUM" > "$RELEASE_NOTES_FILE"
  log_success "Saved release notes to $RELEASE_NOTES_FILE"
fi

echo ""
create_github_release "$VERSION" "$RELEASE_NOTES_FILE"

echo ""
update_latest_branch "$VERSION"

print_release_complete "$VERSION"
