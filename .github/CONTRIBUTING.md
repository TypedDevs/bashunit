# Contributing to bashunit

Welcome! This guide will help you contribute to the bashunit testing framework.

## Quick Start

1. Fork and clone the repository
2. Set up your development environment
3. Find an issue to work on ([good first issues](https://github.com/TypedDevs/bashunit/labels/good%20first%20issue))
4. Make your changes following our guidelines
5. Submit a Pull Request

## Table of Contents

- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Coding Guidelines](#coding-guidelines)
- [Getting Help](#getting-help)

## Code of Conduct

This project follows a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to abide by its terms.

## License

Contributions are licensed under the [MIT License](https://github.com/TypedDevs/bashunit/blob/main/LICENSE).

## Development Setup

### Prerequisites

- Bash 3.2+
- Git
- Make
- [ShellCheck](https://github.com/koalaman/shellcheck#installing)
- [editorconfig-checker](https://github.com/editorconfig-checker/editorconfig-checker#installation)

### Setup

```bash
# Clone and setup
git clone https://github.com/YOUR_USERNAME/bashunit.git
cd bashunit
git remote add upstream https://github.com/TypedDevs/bashunit.git

# Install pre-commit hooks
make pre_commit/install

# Verify setup
make test && make sa && make lint
```

### Documentation Setup (Optional)

For documentation changes:

```bash
nvm use  # Uses .nvmrc version
npm ci
npm run docs:dev
```

## Making Changes

### Finding Issues

- [Good first issues](https://github.com/TypedDevs/bashunit/labels/good%20first%20issue) for new contributors
- [Bug reports](https://github.com/TypedDevs/bashunit/labels/bug)
- [Enhancement requests](https://github.com/TypedDevs/bashunit/labels/enhancement)
- [Documentation issues](https://github.com/TypedDevs/bashunit/labels/documentation)

### Branch Naming Convention

Create descriptive branch names:

```bash
# For new features
git checkout -b feat/add-new-assertion

# For bug fixes
git checkout -b fix/resolve-test-timeout

# For documentation
git checkout -b doc/improve-installation-guide

# For refactoring
git checkout -b ref/simplify-runner-logic
```

## Commit Guidelines

### Format

Use [Conventional Commits](https://conventionalcommits.org/):

```
<type>(<scope>): <description>
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples:**
```bash
feat(assert): add assert_file_contains function
fix(runner): resolve test timeout in parallel execution
docs(readme): update installation instructions
```

### Best Practices

- Keep commits atomic (one logical change)
- Reference issues with "Closes #123"
- Set up git identity:
    ```bash
    git config user.name "Your Name"
    git config user.email "your.email@example.com"
    ```

## 🐛 Reporting Bugs

When reporting bugs, please include:

### Bug Report Template

```markdown
**Description**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run command '...'
2. With these test files '...'
3. See error

**Expected Behavior**
What you expected to happen.

**Actual Behavior**
What actually happened.

**Environment**
- OS: [e.g., macOS 12.0, Ubuntu 20.04]
- Bash version: [e.g., 5.1.8]
- bashunit version: [e.g., 0.24.0]

**Additional Context**
- Test files (if applicable)
- Error messages
- Screenshots (if helpful)
```

Please post code and output as text using [proper markdown formatting](https://guides.github.com/features/mastering-markdown/). Screenshots are welcome for additional context.

## Pull Request Process

### Before Starting

1. Search [existing issues](https://github.com/TypedDevs/bashunit/issues) to avoid duplicates
2. For significant changes, create an issue first to discuss your approach
3. Keep PRs focused (one feature/fix per PR)

### Creating a PR

```bash
# Update your fork
git checkout main
git pull upstream main
git push origin main

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, then test
make test && make sa && make lint

# Push and create PR
git push origin feature/your-feature-name
```

Then create the PR on GitHub, fill out the template, and link related issues.

### What Happens Next?

1. **Automated checks** - GitHub Actions will run tests and code quality checks
2. **Review process** - Maintainers will review your code and provide feedback
3. **Address feedback** - Make requested changes and push updates
4. **Approval and merge** - Once approved, maintainers will merge your PR

### Review Guidelines

- **Be patient** - Reviews take time, especially for complex changes
- **Be responsive** - Address feedback promptly
- **Be collaborative** - Work with reviewers to improve the code
- **Learn from feedback** - Use reviews as learning opportunities

## Documentation

Documentation is built with [VitePress](https://vitepress.dev/).

```bash
nvm use
npm ci
npm run docs:dev  # Start dev server
npm run docs:build  # Build and test
```

**Guidelines:** Keep it simple, include examples, test all code examples.

## Configuration

```bash
cp .env.example .env
```

Edit `.env` with your settings.

## Testing

```bash
make test  # Full test suite
./bashunit tests/**/*_test.sh  # Direct
make test/watch  # With file watching
```

**Guidelines:** Write tests first (TDD), test edge cases, use descriptive names, test on multiple environments.

### Cross-Platform Testing

Supported: Linux (Ubuntu, Alpine), macOS, Windows (WSL/Git Bash)

```bash
# Docker testing
make test/alpine

# NixOS
nix-shell --pure --run "./bashunit --simple --parallel"
```

### Writing Tests

1. Create files ending with `_test.sh`
2. Use descriptive function names: `test_should_return_expected_value()`
3. Follow Arrange/Act/Assert pattern
4. Use appropriate assertions: `assert_equals`, `assert_contains`, `assert_matches`, `assert_exit_code`
5. Test success and failure cases
6. Place in correct directory: `tests/unit/`, `tests/functional/`, `tests/acceptance/`

## Coding Guidelines

### Style

- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use 2 spaces (no tabs)
- Add proper error handling with `set -euo pipefail`
- Use clear variable and function names
- Comment complex logic sparingly

### Required Tools

**ShellCheck** ([install](https://github.com/koalaman/shellcheck#installing)):
```bash
make sa  # Recommended
find . -name "*.sh" -not -path "./local/*" -exec shellcheck -xC {} \;  # Direct
```

**EditorConfig Checker** ([install](https://github.com/editorconfig-checker/editorconfig-checker#installation)):
```bash
make lint  # Recommended
editorconfig-checker  # Direct
```

**Pre-commit hooks** (recommended):
```bash
make pre_commit/install
```

### Checklist

- [ ] `make sa` passes
- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] Functions documented
- [ ] Error handling robust

### Function Documentation

```bash
##
# Brief description
# Arguments: $1 - first arg, $2 - second arg (optional)
# Returns: 0 on success, 1 on failure
# Example: my_function "input" "optional"
##
function my_function() {
    local input="$1"
    local optional="${2:-default}"
    # Implementation
}
```

## Getting Help

- **New contributors:** [Good first issues](https://github.com/TypedDevs/bashunit/labels/good%20first%20issue)
- **Questions:** [GitHub Discussions](https://github.com/TypedDevs/bashunit/discussions)
- **Documentation:** [bashunit.typeddevs.com](https://bashunit.typeddevs.com/)
- **Bug reports:** [Create an issue](https://github.com/TypedDevs/bashunit/issues/new/choose)
- **Feature requests:** [Create an issue](https://github.com/TypedDevs/bashunit/issues/new/choose)

## Architecture Decisions

For significant changes (API changes, major features, breaking changes), create an [ADR](https://adr.github.io/) using these [templates](https://github.com/joelparkerhenderson/architecture-decision-record).

## Releases

Maintainers handle releases following [Semantic Versioning](https://semver.org/).

---

**Ready to contribute?**

1. [Fork the project](https://github.com/TypedDevs/bashunit/fork)
2. [Find an issue](https://github.com/TypedDevs/bashunit/issues)
3. [Set up your environment](#development-setup)
4. [Create a pull request](#pull-request-process)

Thank you for contributing to bashunit!
