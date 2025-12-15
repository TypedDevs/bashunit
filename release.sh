#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Exit codes
declare -r EXIT_SUCCESS=0
declare -r EXIT_VALIDATION_ERROR=1
# shellcheck disable=SC2034 # Reserved for future use
declare -r EXIT_EXECUTION_ERROR=2

# Constants
GITHUB_REPO_PATH="TypedDevs/bashunit"
GITHUB_REPO_URL="https://github.com/${GITHUB_REPO_PATH}"
RELEASE_FILES=("bashunit" "install.sh" "package.json" "CHANGELOG.md")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Mode flags
DRY_RUN=false
SANDBOX_MODE=false
FORCE_MODE=false
VERBOSE_MODE=false
JSON_OUTPUT=false
WITH_GH_RELEASE=false

# State tracking
RELEASE_STATE_DIR=""
BACKUP_DIR=""
SANDBOX_DIR=""
COMPLETED_STEPS=()

# Version tracking
VERSION=""
CURRENT_VERSION=""

function release::show_usage() {
  cat >&2 <<EOF
Usage: ./release.sh <version> [options]

Arguments:
  version     The new version number (e.g., 0.30.0)

Options:
  --dry-run         Preview changes without modifying any files
  --sandbox         Run in sandbox mode (isolated temp directory)
  --force           Skip all interactive confirmations (for CI)
  --verbose         Enable detailed logging
  --json            Output machine-readable JSON summary
  --with-gh-release Create the GitHub release automatically
  --rollback        Restore files from most recent backup
  -h, --help        Show this help message

Exit Codes:
  0    Success
  1    Validation error (invalid version, pre-flight check failed)
  2    Execution error (build failed, git failed)

Examples:
  ./release.sh 0.31.0                    # Interactive release
  ./release.sh 0.31.0 --dry-run          # Preview changes
  ./release.sh 0.31.0 --sandbox          # Test in isolated sandbox
  ./release.sh 0.31.0 --force --json     # CI mode with JSON output
  ./release.sh --rollback                # Restore from backup
EOF
}

function release::log_info() {
  echo -e "${BLUE}[INFO]${NC} $1" >&2
}

function release::log_success() {
  echo -e "${GREEN}[OK]${NC} $1" >&2
}

function release::log_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

function release::log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

function release::log_dry_run() {
  echo -e "${YELLOW}[DRY-RUN]${NC} $1" >&2
}

function release::log_verbose() {
  if [[ "$VERBOSE_MODE" == true ]]; then
    echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
  fi
}

function release::log_sandbox() {
  echo -e "${YELLOW}[SANDBOX]${NC} $1" >&2
}

function release::error_with_suggestion() {
  local error=$1
  local suggestion=$2
  release::log_error "$error"
  echo -e "  ${YELLOW}Suggestion:${NC} $suggestion" >&2
}

function release::blank_line() {
  echo "" >&2
}

function release::update_file_pattern() {
  local file=$1
  local pattern=$2
  local replacement=$3
  local description=$4

  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would update $description in $file"
    return
  fi

  sed -i.bak "s|$pattern|$replacement|" "$file"
  rm -f "$file.bak"
  release::log_success "Updated $description in $file"
}

#########################
### PRE-FLIGHT CHECKS ###
#########################

function release::preflight::check_gh_installed() {
  release::log_verbose "Checking if gh CLI is installed..."
  if ! command -v gh >/dev/null 2>&1; then
    release::error_with_suggestion \
      "gh CLI is not installed" \
      "Install from https://cli.github.com/"
    return 1
  fi
  release::log_verbose "gh CLI is installed"
  return 0
}

function release::preflight::check_gh_auth() {
  release::log_verbose "Checking gh authentication..."
  if ! gh auth status >/dev/null 2>&1; then
    release::error_with_suggestion \
      "Not authenticated with GitHub" \
      "Run 'gh auth login' to authenticate"
    return 1
  fi
  release::log_verbose "gh is authenticated"
  return 0
}

function release::preflight::check_git_clean() {
  release::log_verbose "Checking git working directory..."
  if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
    release::error_with_suggestion \
      "Working directory has uncommitted changes" \
      "Commit or stash changes first: git stash"
    return 1
  fi
  release::log_verbose "Working directory is clean"
  return 0
}

function release::preflight::check_branch_main() {
  release::log_verbose "Checking current branch..."
  local current_branch
  current_branch=$(git branch --show-current 2>/dev/null)
  if [[ "$current_branch" != "main" ]]; then
    release::error_with_suggestion \
      "Not on main branch (currently on: $current_branch)" \
      "Switch to main: git checkout main"
    return 1
  fi
  release::log_verbose "On main branch"
  return 0
}

function release::preflight::check_network() {
  release::log_verbose "Checking network connectivity..."
  if ! curl --silent --head --fail --max-time 5 https://github.com >/dev/null 2>&1; then
    release::error_with_suggestion \
      "Cannot reach github.com" \
      "Check your network connection"
    return 1
  fi
  release::log_verbose "Network connectivity OK"
  return 0
}

function release::preflight::check_required_files() {
  release::log_verbose "Checking required files..."
  local required_files=("${RELEASE_FILES[@]}" "build.sh")
  local missing=()

  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing+=("$file")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    release::error_with_suggestion \
      "Required files missing: ${missing[*]}" \
      "Ensure you're in the project root directory"
    return 1
  fi
  release::log_verbose "All required files present"
  return 0
}

function release::preflight::check_changelog_unreleased() {
  release::log_verbose "Checking CHANGELOG.md for Unreleased section..."
  if ! grep -q "^## Unreleased$" CHANGELOG.md 2>/dev/null; then
    release::error_with_suggestion \
      "CHANGELOG.md is missing '## Unreleased' section" \
      "Add '## Unreleased' section at the top of CHANGELOG.md"
    return 1
  fi

  # Check if there's content between ## Unreleased and next ## [
  local unreleased_content
  unreleased_content=$(awk '/^## Unreleased$/,/^## \[/' CHANGELOG.md | grep -v "^## " | grep -v "^$" | head -1)
  if [[ -z "$unreleased_content" ]]; then
    release::error_with_suggestion \
      "CHANGELOG.md Unreleased section has no content" \
      "Add release notes under '## Unreleased' section"
    return 1
  fi
  release::log_verbose "CHANGELOG.md has Unreleased section with content"
  return 0
}

function release::preflight::check_all() {
  local checks_passed=true
  local preflight_checks=(
    "release::preflight::check_gh_installed"
    "release::preflight::check_gh_auth"
    "release::preflight::check_git_clean"
    "release::preflight::check_branch_main"
    "release::preflight::check_network"
    "release::preflight::check_required_files"
    "release::preflight::check_changelog_unreleased"
  )

  release::log_info "Running pre-flight checks..."

  for check in "${preflight_checks[@]}"; do
    if ! "$check"; then
      checks_passed=false
    fi
  done

  if [[ "$checks_passed" == true ]]; then
    release::log_success "All pre-flight checks passed"
    return 0
  else
    release::log_error "Pre-flight checks failed"
    return 1
  fi
}

#########################
### BACKUP & ROLLBACK ###
#########################

function release::backup::init() {
  RELEASE_STATE_DIR=".release-state"
  BACKUP_DIR="$RELEASE_STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  release::log_verbose "Created backup directory: $BACKUP_DIR"
}

function release::backup::save_file() {
  local file=$1
  if [[ -f "$file" ]]; then
    cp "$file" "$BACKUP_DIR/"
    release::log_verbose "Backed up: $file"
  fi
}

function release::backup::save_all() {
  release::log_verbose "Backing up files before modification..."
  for file in "${RELEASE_FILES[@]}"; do
    release::backup::save_file "$file"
  done
  release::log_verbose "All files backed up to $BACKUP_DIR"
}

function release::state::record_step() {
  local step=$1
  COMPLETED_STEPS+=("$step")
  release::log_verbose "Completed step: $step"
}

function release::rollback::restore_files() {
  if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
    release::log_error "No backup directory found"
    return 1
  fi

  release::log_info "Restoring files from backup..."
  for file in "$BACKUP_DIR"/*; do
    if [[ -f "$file" ]]; then
      local filename
      filename=$(basename "$file")
      cp "$file" "./$filename"
      release::log_verbose "Restored: $filename"
    fi
  done
  release::log_success "Files restored from backup"
}

function release::rollback::auto() {
  release::log_error "Release failed. Initiating rollback..."
  release::rollback::restore_files || true
  release::log_info "Rollback complete. Files restored to pre-release state."
  release::log_info "Manual rollback command if needed: ./release.sh --rollback"
}

function release::rollback::manual() {
  # Find most recent backup
  if [[ ! -d ".release-state" ]]; then
    release::log_error "No .release-state directory found"
    exit $EXIT_VALIDATION_ERROR
  fi

  local latest_backup
  latest_backup=$(find .release-state -maxdepth 1 -type d -name 'backup-*' 2>/dev/null | sort -r | head -1)

  if [[ -z "$latest_backup" ]]; then
    release::log_error "No backup found in .release-state"
    exit $EXIT_VALIDATION_ERROR
  fi

  release::log_info "Found backup: $latest_backup"
  BACKUP_DIR="$latest_backup"
  release::rollback::restore_files
  release::log_success "Manual rollback complete"
}

function release::cleanup::state_dir() {
  if [[ -d "$RELEASE_STATE_DIR" ]]; then
    rm -rf "$RELEASE_STATE_DIR"
    release::log_verbose "Cleaned up $RELEASE_STATE_DIR"
  fi
}

function release::setup_rollback_trap() {
  trap 'release::rollback::auto' ERR
}

function release::clear_rollback_trap() {
  trap - ERR
}

#########################
###   SANDBOX MODE    ###
#########################

function release::sandbox::create() {
  SANDBOX_DIR=$(mktemp -d "/tmp/bashunit-release-sandbox-XXXX")
  release::log_info "Creating sandbox at: $SANDBOX_DIR"

  # Copy repo content excluding .git
  rsync -a --exclude='.git' --exclude='.release-state' --exclude='node_modules' . "$SANDBOX_DIR/"
  release::log_verbose "Copied project files to sandbox"
}

function release::sandbox::setup_git() {
  cd "$SANDBOX_DIR"
  git init --quiet
  git config user.name "Release Sandbox"
  git config user.email "sandbox@local"
  git add .
  git commit --quiet -m "Initial sandbox state"
  release::log_verbose "Initialized git repository in sandbox"
}

function release::sandbox::mock_gh() {
  # Create gh mock function that logs instead of executing
  gh() {
    release::log_sandbox "Would execute: gh $*"
    case "$1" in
      release)
        release::log_sandbox "GitHub release would be created"
        return 0
        ;;
      api)
        # Return empty for contributor lookup
        echo ""
        return 0
        ;;
      auth)
        # Auth status check - return success in sandbox
        return 0
        ;;
    esac
    return 0
  }
  export -f gh
}

function release::sandbox::mock_git_push() {
  # Override git push to prevent actual pushes
  local original_git
  original_git=$(command -v git)

  git() {
    if [[ "$1" == "push" ]]; then
      release::log_sandbox "Would execute: git $*"
      return 0
    fi
    "$original_git" "$@"
  }
  export -f git
}

function release::sandbox::show_results() {
  release::blank_line
  release::log_info "=== SANDBOX RESULTS ==="
  release::blank_line

  release::log_info "Files changed:"
  git diff HEAD~1 --stat 2>/dev/null || true
  release::blank_line

  release::log_info "Commits made:"
  git log --oneline HEAD~1..HEAD 2>/dev/null || git log --oneline -1 2>/dev/null
  release::blank_line

  if [[ -f "/tmp/bashunit-release-notes-${VERSION}.md" ]]; then
    release::log_info "Release notes preview:"
    echo "----------------------------------------" >&2
    cat "/tmp/bashunit-release-notes-${VERSION}.md" >&2
    echo "----------------------------------------" >&2
  fi
}

function release::sandbox::cleanup() {
  local response
  release::blank_line
  echo -en "${YELLOW}Keep sandbox for inspection? [y/N]: ${NC}" >&2
  read -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    release::log_info "Sandbox preserved at: $SANDBOX_DIR"
    release::log_info "To clean up later: rm -rf $SANDBOX_DIR"
  else
    rm -rf "$SANDBOX_DIR"
    release::log_success "Sandbox cleaned up"
  fi
}

function release::sandbox::run() {
  release::log_warning "SANDBOX MODE - Running in isolated environment"
  release::blank_line

  # Limited pre-flight checks for sandbox (only file checks, not git/gh)
  if ! release::preflight::check_required_files; then
    exit $EXIT_VALIDATION_ERROR
  fi

  # Create and setup sandbox
  release::sandbox::create
  release::sandbox::setup_git
  release::sandbox::mock_gh
  release::sandbox::mock_git_push

  release::log_info "Starting sandbox release simulation..."
  release::blank_line

  # Run release steps in sandbox (cd already done in setup_git)
  release::update_bashunit_version "$VERSION"
  release::update_install_version "$VERSION"
  release::update_package_json_version "$VERSION"
  release::update_changelog "$VERSION" "$CURRENT_VERSION"

  release::blank_line
  release::build_project

  release::blank_line
  release::update_checksum

  release::blank_line
  # Commit changes (confirmations skipped in sandbox)
  release::log_info "Creating release commit..."
  git add "${RELEASE_FILES[@]}"
  git commit -m "release: $VERSION" -n
  release::log_success "Created commit"
  git tag "$VERSION"
  release::log_success "Created tag $VERSION"

  # Generate release notes
  RELEASE_NOTES_FILE="/tmp/bashunit-release-notes-${VERSION}.md"
  CHECKSUM=$(release::get_checksum)
  release::generate_release_notes "$VERSION" "$CURRENT_VERSION" "$CHECKSUM" > "$RELEASE_NOTES_FILE"
  release::log_success "Generated release notes"

  # Show what would happen with push/gh release
  release::log_sandbox "Would push: git push origin main"
  release::log_sandbox "Would push tag: git push origin $VERSION"
  release::log_sandbox "Would create GitHub release with assets: bin/bashunit, bin/checksum"
  release::log_sandbox "Would update 'latest' branch"

  # Show results
  release::sandbox::show_results

  release::blank_line
  echo "========================================" >&2
  echo -e "${GREEN}Sandbox release simulation complete!${NC}" >&2
  echo "========================================" >&2
  release::blank_line

  # Go back to original directory before cleanup prompt
  cd "$SCRIPT_DIR"
  release::sandbox::cleanup
}

function release::validate_semver() {
  local version=$1
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    release::log_error "Invalid version format: $version"
    release::log_error "Version must be in semver format (e.g., 0.30.0)"
    exit $EXIT_VALIDATION_ERROR
  fi
}

function release::get_current_version() {
  grep -o 'BASHUNIT_VERSION="[^"]*"' bashunit | cut -d'"' -f2
}

function release::version_gt() {
  # Returns 0 if $1 > $2
  local v1=$1
  local v2=$2

  if [[ "$v1" == "$v2" ]]; then
    return 1
  fi

  local i
  local ver1
  local ver2
  IFS=. read -ra ver1 <<< "$v1"
  IFS=. read -ra ver2 <<< "$v2"

  for ((i=0; i<3; i++)); do
    if ((ver1[i] > ver2[i])); then
      return 0
    elif ((ver1[i] < ver2[i])); then
      return 1
    fi
  done

  return 1
}

function release::update_bashunit_version() {
  local new_version=$1
  release::update_file_pattern \
    "bashunit" \
    "BASHUNIT_VERSION=\"[^\"]*\"" \
    "BASHUNIT_VERSION=\"$new_version\"" \
    "BASHUNIT_VERSION"
}

function release::update_install_version() {
  local new_version=$1
  release::update_file_pattern \
    "install.sh" \
    "LATEST_BASHUNIT_VERSION=\"[^\"]*\"" \
    "LATEST_BASHUNIT_VERSION=\"$new_version\"" \
    "LATEST_BASHUNIT_VERSION"
}

function release::update_package_json_version() {
  local new_version=$1
  release::update_file_pattern \
    "package.json" \
    "\"version\": \"[^\"]*\"" \
    "\"version\": \"$new_version\"" \
    "version"
}

function release::update_changelog() {
  local new_version=$1
  local current_version=$2
  local file="CHANGELOG.md"
  local today
  today=$(date +%Y-%m-%d)
  local compare_url="${GITHUB_REPO_URL}/compare/${current_version}...${new_version}"

  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would update $file:"
    release::log_dry_run "  - Add new '## Unreleased' section"
    release::log_dry_run "  - Convert current Unreleased to ## [$new_version]($compare_url) - $today"
    return
  fi

  # Create the new version header
  local new_header="## [$new_version]($compare_url) - $today"

  # Replace "## Unreleased" with new Unreleased + version header
  sed -i.bak "s|^## Unreleased$|## Unreleased\n\n$new_header|" "$file"
  rm -f "$file.bak"
  release::log_success "Updated $file with version $new_version"
}

function release::build_project() {
  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would run: ./build.sh bin"
    return
  fi

  release::log_info "Building project..."
  ./build.sh bin
  release::log_success "Build completed"
}

function release::get_checksum() {
  if [[ -f "bin/checksum" ]]; then
    awk '{print $1}' bin/checksum
  else
    echo ""
  fi
}

function release::get_contributors() {
  local prev_version=$1

  # Get GitHub handles of commit authors since previous version
  # Uses HEAD since the new version tag doesn't exist yet
  gh api "/repos/${GITHUB_REPO_PATH}/compare/${prev_version}...HEAD" \
    --jq '.commits[].author.login' 2>/dev/null | sort -u | grep -v '^$' || true
}

function release::generate_release_notes() {
  local new_version=$1
  local prev_version=$2
  local checksum=$3

  # Extract content from the latest version header (first ## [) until the next version header
  # Transform changelog sections to release format with emojis
  awk '/^## \[/{if(found) exit; found=1; next} found' CHANGELOG.md | \
    sed 's/^### Added$/## ✨ Improvements/' | \
    sed 's/^### Changed$/## 🛠️ Changes/' | \
    sed 's/^### Fixed$/## 🐛 Bug Fixes/' | \
    sed 's/^### Performance$/## ⚡ Performance/'

  # Add contributors section
  local contributors
  contributors=$(release::get_contributors "$prev_version")
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
  local compare_url="${GITHUB_REPO_URL}/compare/$prev_version...$new_version"
  echo "**Full Changelog:** [$prev_version...$new_version]($compare_url)"
}

function release::create_github_release() {
  local version=$1
  local notes_file=$2

  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would create GitHub release $version with assets:"
    release::log_dry_run "  - bin/bashunit"
    release::log_dry_run "  - bin/checksum"
    return
  fi

  if [[ "$WITH_GH_RELEASE" != true ]]; then
    release::log_info "To create the GitHub release, run:"
    echo -e "  ${BLUE}gh release create $version bin/bashunit bin/checksum \\"
    echo -e "    --title \"$version\" --notes-file \"$notes_file\"${NC}"
    echo ""
    release::log_info "Or re-run with --with-gh-release flag"
    return
  fi

  if ! release::confirm_action "Do you want to create the GitHub release now?"; then
    release::log_warning "Skipping GitHub release creation"
    return
  fi

  release::log_info "Creating GitHub release..."
  gh release create "$version" \
    bin/bashunit \
    bin/checksum \
    --title "$version" \
    --notes-file "$notes_file"

  release::log_success "GitHub release $version created with assets"
}

function release::update_checksum() {
  local file="package.json"
  local checksum
  checksum=$(release::get_checksum)

  if [[ -z "$checksum" ]]; then
    release::log_error "Could not read checksum from bin/checksum"
    exit $EXIT_VALIDATION_ERROR
  fi

  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would update checksum in $file to $checksum"
    return
  fi

  sed -i.bak "s/\"checksum\": \"[^\"]*\"/\"checksum\": \"$checksum\"/" "$file"
  rm -f "$file.bak"
  release::log_success "Updated checksum in $file"
}

function release::show_diff() {
  echo ""
  release::log_info "Changes to be committed:"
  echo "----------------------------------------"
  git status --short
  git diff HEAD --color=always
  echo "----------------------------------------"
  echo ""
}

function release::confirm_action() {
  local prompt=$1
  local response

  # In force mode, auto-confirm all actions
  if [[ "$FORCE_MODE" == true ]]; then
    release::log_info "[FORCE] Auto-confirming: $prompt"
    return 0
  fi

  echo -en "${YELLOW}$prompt [y/N]: ${NC}" >&2
  read -r response

  if [[ "$response" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

#########################
###    JSON OUTPUT    ###
#########################

function release::json::summary() {
  local status=$1
  local steps_json=""

  # Build steps array
  if [[ ${#COMPLETED_STEPS[@]} -gt 0 ]]; then
    steps_json=$(printf '"%s",' "${COMPLETED_STEPS[@]}" | sed 's/,$//')
  fi

  cat <<EOF
{
  "status": "$status",
  "version": "$VERSION",
  "current_version": "$CURRENT_VERSION",
  "sandbox_mode": $SANDBOX_MODE,
  "dry_run": $DRY_RUN,
  "force_mode": $FORCE_MODE,
  "completed_steps": [$steps_json],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

function release::git_commit_and_tag() {
  local new_version=$1

  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would create commit: release: $new_version"
    release::log_dry_run "Would create tag: $new_version"
    release::log_dry_run "Would push commit and tag to origin"
    return
  fi

  release::show_diff

  if ! release::confirm_action "Do you want to commit these changes?"; then
    release::log_warning "Skipping git commit"
    return
  fi

  git add "${RELEASE_FILES[@]}"
  git commit -m "release: $new_version" -n
  release::log_success "Created commit"

  git tag "$new_version"
  release::log_success "Created tag $new_version"

  if release::confirm_action "Do you want to push commit and tag to origin?"; then
    git push origin main
    git push origin "$new_version"
    release::log_success "Pushed to origin"
  else
    release::log_warning "Skipping push (run manually: git push origin main && git push origin $new_version)"
  fi
}

function release::update_latest_branch() {
  local new_version=$1

  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would update 'latest' branch:"
    release::log_dry_run "  git checkout latest"
    release::log_dry_run "  git rebase $new_version"
    release::log_dry_run "  git push origin latest --force"
    release::log_dry_run "  git checkout main"
    return
  fi

  if ! release::confirm_action "Do you want to update 'latest' branch to trigger docs deployment?"; then
    release::log_warning "Skipping 'latest' branch update"
    echo ""
    echo "To update manually, run:"
    echo -e "  ${BLUE}git checkout latest && git rebase $new_version \\"
    echo -e "    && git push origin latest --force && git checkout main${NC}"
    return
  fi

  release::log_info "Updating 'latest' branch..."
  git checkout latest
  git rebase "$new_version"
  git push origin latest --force
  git checkout main
  release::log_success "Updated 'latest' branch - docs deployment triggered"
}

function release::print_release_complete() {
  local new_version=$1

  release::blank_line
  echo "========================================" >&2
  echo -e "${GREEN}Release $new_version complete!${NC}" >&2
  echo "========================================" >&2
  release::blank_line
}

#########################
######### MAIN ##########
#########################

function release::main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --sandbox)
        SANDBOX_MODE=true
        shift
        ;;
      --force)
        FORCE_MODE=true
        shift
        ;;
      --verbose)
        VERBOSE_MODE=true
        shift
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      --with-gh-release)
        WITH_GH_RELEASE=true
        shift
        ;;
      --rollback)
        release::rollback::manual
        exit $?
        ;;
      -h|--help)
        release::show_usage
        exit $EXIT_SUCCESS
        ;;
      *)
        if [[ -z "$VERSION" ]]; then
          VERSION=$1
        else
          release::log_error "Unknown argument: $1"
          release::show_usage
          exit $EXIT_VALIDATION_ERROR
        fi
        shift
        ;;
    esac
  done

  # Validate version argument
  if [[ -z "$VERSION" ]]; then
    release::log_error "Version argument is required"
    release::show_usage
    exit $EXIT_VALIDATION_ERROR
  fi

  release::validate_semver "$VERSION"

  # Get current version
  CURRENT_VERSION=$(release::get_current_version)
  release::log_info "Current version: $CURRENT_VERSION"
  release::log_info "New version: $VERSION"

  # Validate new version is greater
  if ! release::version_gt "$VERSION" "$CURRENT_VERSION"; then
    release::error_with_suggestion \
      "New version ($VERSION) must be greater than current version ($CURRENT_VERSION)" \
      "Use a version number higher than $CURRENT_VERSION"
    exit $EXIT_VALIDATION_ERROR
  fi

  # Route to appropriate mode
  if [[ "$SANDBOX_MODE" == true ]]; then
    release::sandbox::run
    if [[ "$JSON_OUTPUT" == true ]]; then
      release::json::summary "success"
    fi
    exit $EXIT_SUCCESS
  fi

  if [[ "$DRY_RUN" == true ]]; then
    release::blank_line
    release::log_warning "DRY-RUN MODE - No files will be modified"
    release::blank_line
  else
    # Run pre-flight checks for real releases
    if ! release::preflight::check_all; then
      if [[ "$JSON_OUTPUT" == true ]]; then
        release::json::summary "failed"
      fi
      exit $EXIT_VALIDATION_ERROR
    fi

    # Initialize backup/rollback system
    release::backup::init
    release::backup::save_all
    release::setup_rollback_trap
  fi

  # Execute release steps
  release::log_info "Starting release process..."
  release::blank_line

  release::update_bashunit_version "$VERSION"
  release::state::record_step "update_bashunit_version"

  release::update_install_version "$VERSION"
  release::state::record_step "update_install_version"

  release::update_package_json_version "$VERSION"
  release::state::record_step "update_package_json_version"

  release::update_changelog "$VERSION" "$CURRENT_VERSION"
  release::state::record_step "update_changelog"

  release::blank_line
  release::build_project
  release::state::record_step "build_project"

  release::blank_line
  release::update_checksum
  release::state::record_step "update_checksum"

  release::blank_line
  release::git_commit_and_tag "$VERSION"
  release::state::record_step "git_commit_and_tag"

  # Generate formatted release notes
  RELEASE_NOTES_FILE="/tmp/bashunit-release-notes-${VERSION}.md"
  CHECKSUM=$(release::get_checksum)

  release::blank_line
  if [[ "$DRY_RUN" == true ]]; then
    release::log_dry_run "Would save release notes to $RELEASE_NOTES_FILE"
    release::log_dry_run "Release notes content:"
    echo "----------------------------------------" >&2
    release::generate_release_notes "$VERSION" "$CURRENT_VERSION" "$CHECKSUM" >&2
    echo "----------------------------------------" >&2
  else
    release::generate_release_notes "$VERSION" "$CURRENT_VERSION" "$CHECKSUM" > "$RELEASE_NOTES_FILE"
    release::log_success "Saved release notes to $RELEASE_NOTES_FILE"
  fi
  release::state::record_step "generate_release_notes"

  release::blank_line
  release::create_github_release "$VERSION" "$RELEASE_NOTES_FILE"
  release::state::record_step "create_github_release"

  release::blank_line
  release::update_latest_branch "$VERSION"
  release::state::record_step "update_latest_branch"

  # Cleanup on success
  if [[ "$DRY_RUN" != true ]]; then
    release::clear_rollback_trap
    release::cleanup::state_dir
  fi

  release::print_release_complete "$VERSION"

  # Output JSON summary if requested (to stdout)
  if [[ "$JSON_OUTPUT" == true ]]; then
    release::json::summary "success"
  fi
}

# Only run main when script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  release::main "$@"
fi
