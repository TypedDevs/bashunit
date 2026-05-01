# Installation

**bashunit** ships as a single-file executable. Pick the option that fits your project: `install.sh` (universal), [npm](#npm) (Node.js projects), [Brew](#brew) (macOS/Linux global), [MacPorts](#macports), or [bashdep](#bashdep).

## Requirements

bashunit requires **Bash 3.0** or newer. On Windows use [WSL](https://learn.microsoft.com/windows/wsl/install).

## install.sh

There is a tool that will generate an executable with the whole library in a single file:

::: code-group
```bash [Linux/Mac]
curl -s https://bashunit.typeddevs.com/install.sh | bash
```

```bash [Windows]
# IMPORTANT: You need WSL (Windows Subsystem for Linux) to run bashunit
#
# Step 1: Install WSL if you haven't already
#   - Open PowerShell as Administrator
#   - Run: wsl --install
#   - Restart your computer
#
# Step 2: Open your WSL terminal and run:
curl -s https://bashunit.typeddevs.com/install.sh | bash
```
:::

This will create a file inside a lib folder, such as `lib/bashunit`.

#### Verify

```bash-vue
# Verify the sha256sum for latest stable: {{ pkg.version }}
DIR="lib"; KNOWN_HASH="{{pkg.checksum}}"; FILE="$DIR/bashunit"; [ "$(shasum -a 256 "$FILE" | awk '{ print $1 }')" = "$KNOWN_HASH" ] && echo -e "✓ \033[1mbashunit\033[0m verified." || { echo -e "✗ \033[1mbashunit\033[0m corrupt"; rm "$FILE"; }
```

:::tip
You can find the checksum for each version inside [GitHub's releases](https://github.com/TypedDevs/bashunit/releases). E.g.:
```-vue
https://github.com/TypedDevs/bashunit/releases/download/{{ pkg.version }}/checksum
```
:::

#### Define custom tag and folder

The installation script can receive arguments (in any order):

::: code-group
```bash [Linux/Mac]
curl -s https://bashunit.typeddevs.com/install.sh | bash -s [dir] [version]
```

```bash [Windows]
# IMPORTANT: You need WSL (Windows Subsystem for Linux) to run bashunit
#
# Step 1: Install WSL if you haven't already
#   - Open PowerShell as Administrator
#   - Run: wsl --install
#   - Restart your computer
#
# Step 2: Open your WSL terminal and run:
curl -s https://bashunit.typeddevs.com/install.sh | bash -s [dir] [version]
```
:::

- `[dir]`: the destiny directory to save the executable bashunit; `lib` by default
- `[version]`: the [release](https://github.com/TypedDevs/bashunit/releases) to download, for instance `{{ pkg.version }}`; `latest` by default.

::: tip
You can use `beta` as `[version]` to get the next non-stable preview release.
We try to keep it stable, but there is no promise that we won't change functions or their signatures without prior notice.
:::

::: tip
Committing (or not) this file to your project it's up to you. In the end, it is a dev dependency.
:::

## npm

[bashunit on npm](https://www.npmjs.com/package/bashunit) is the recommended option for Node.js projects.

::: code-group
```bash [Per-project (recommended)]
npm install --save-dev bashunit
npx bashunit tests/
```

```bash [Global]
npm install -g bashunit
bashunit tests/
```

```bash [One-shot]
# No install, runs the latest release
npx bashunit@latest tests/
```
:::

Add a script to your `package.json` so contributors and CI run the same command:

```json
{
  "scripts": {
    "test:sh": "bashunit tests/"
  },
  "devDependencies": {
    "bashunit": "^{{ pkg.version }}"
  }
}
```

::: warning
The npm package only ships the prebuilt single-file binary (no `src/` tree), and is restricted to `darwin` and `linux`. You cannot `source` internals from `node_modules/bashunit/` - use the `bashunit` command. To vendor or extend the framework, use [install.sh](#install-sh) or clone the repository.
:::

## Brew

You can install **bashunit** globally on macOS or Linux using brew.

```bash
brew install bashunit
```

## MacPorts

On macOS, you can also install **bashunit** via [MacPorts](https://www.macports.org):

```bash
sudo port install bashunit
```

## bashdep

You can manage your dependencies using [bashdep](https://github.com/Chemaclass/bashdep),
a simple dependency manager for bash.

::: code-group
```bash-vue [Linux/Mac - install-dependencies.sh]
# Ensure bashdep is installed
[ ! -f lib/bashdep ] && {
  mkdir -p lib
  curl -sLo lib/bashdep \
    https://github.com/Chemaclass/bashdep/releases/download/0.1/bashdep
  chmod +x lib/bashdep
}

# Add latest bashunit release to your dependencies
DEPENDENCIES=(
  "https://github.com/TypedDevs/bashunit/releases/download/{{ pkg.version }}/bashunit"
)

# Load, configure and run bashdep
source lib/bashdep
bashdep::setup dir="lib" silent=false
bashdep::install "${DEPENDENCIES[@]}"
```

```bash-vue [Windows - install-dependencies.sh]
# IMPORTANT: You need WSL (Windows Subsystem for Linux) to run bashunit
#
# Step 1: Install WSL if you haven't already
#   - Open PowerShell as Administrator
#   - Run: wsl --install
#   - Restart your computer
#
# Step 2: Open your WSL terminal and run:

# Ensure bashdep is installed
[ ! -f lib/bashdep ] && {
  mkdir -p lib
  curl -sLo lib/bashdep \
    https://github.com/Chemaclass/bashdep/releases/download/0.1/bashdep
  chmod +x lib/bashdep
}

# Add latest bashunit release to your dependencies
DEPENDENCIES=(
  "https://github.com/TypedDevs/bashunit/releases/download/{{ pkg.version }}/bashunit"
)

# Load, configure and run bashdep
source lib/bashdep
bashdep::setup dir="lib" silent=false
bashdep::install "${DEPENDENCIES[@]}"
```
```[Output]
Downloading 'bashunit' to 'lib'...
> bashunit installed successfully in 'lib'
```
:::

## GitHub Actions

::: code-group
```yaml [via install.sh]
# .github/workflows/bashunit-tests.yml
name: Tests
on: [pull_request, push]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: curl -s https://bashunit.typeddevs.com/install.sh | bash
      - run: ./lib/bashunit tests
```

```yaml [via npm]
# .github/workflows/bashunit-tests.yml
name: Tests
on: [pull_request, push]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx bashunit tests/
```
:::

::: tip
See bashunit's own pipeline for a real example: https://github.com/TypedDevs/bashunit/blob/main/.github/workflows/tests.yml
:::

<script setup>
import pkg from '../package.json'
</script>
