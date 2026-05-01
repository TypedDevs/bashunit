# Installation

Although there's no Bash script dependency manager like npm for JavaScript, Maven for Java, pip for Python, or composer for PHP;
you can add **bashunit** as a dependency in your repository according to your preferences.

Here, we provide different options that you can use to install **bashunit** in your application.

## Requirements

bashunit requires **Bash 3.0** or newer.

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

## npm

If your project already uses Node.js tooling (e.g. a JavaScript or TypeScript repo), you can install **bashunit** directly from the [npm registry](https://www.npmjs.com/package/bashunit).

The npm package ships only the prebuilt single-file binary plus `LICENSE` and `README.md`; it does not include the source tree.

### Per-project (recommended)

Install **bashunit** as a `devDependency` so the version is pinned in your `package.json` and reproducible across machines and CI:

```bash
npm install --save-dev bashunit
```

Add a script to your `package.json`:

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

Then run:

```bash
npm run test:sh
# or invoke directly via npx
npx bashunit tests/
```

### Global

Install **bashunit** system-wide so the `bashunit` command is available on your `PATH`:

```bash
npm install -g bashunit
bashunit --version
bashunit tests/
```

### One-shot, no install

`npx` can download and run the latest release on demand, useful for quick tries or ephemeral CI jobs:

```bash
npx bashunit@latest tests/
```

### Example consumer project

```
my-app/
├── package.json          # has "bashunit" in devDependencies
├── src/
│   └── deploy.sh
└── tests/
    └── deploy_test.sh
```

```bash [tests/deploy_test.sh]
#!/usr/bin/env bash

source "$(dirname "$0")/../src/deploy.sh"

function test_deploy_returns_url() {
  assert_equals "https://example.com" "$(get_deploy_url)"
}
```

Run from the project root:

```bash
npx bashunit tests/
```

### GitHub Actions with npm

```yaml
name: Tests

on:
  pull_request:
  push:
    branches: [main]

jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npx bashunit tests/
```

::: tip
The npm package is restricted to `darwin` and `linux`; on Windows use [WSL](https://learn.microsoft.com/windows/wsl/install). bashunit still requires **Bash 3.0 or newer** at runtime - npm does not enforce this, the `bashunit` script does.
:::

::: warning
Because only the prebuilt single-file binary is shipped, you cannot `source` bashunit internals from inside `node_modules/bashunit/`. Use the `bashunit` command directly. If you need to extend or vendor the framework, install via [install.sh](#install-sh) or clone the repository.
:::

## GitHub Actions

```yaml
# example: .github/workflows/bashunit-tests.yml
name: Tests

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  tests:
    name: "Run tests"
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: "Install bashunit"
        run: |
          curl -s https://bashunit.typeddevs.com/install.sh > install.sh
          chmod +x install.sh
          ./install.sh

      - name: "Test"
        run: "./lib/bashunit tests"
```

::: tip
Get inspiration from the pipelines running on the bashunit-project itself: https://github.com/TypedDevs/bashunit/blob/main/.github/workflows/tests.yml
:::

<script setup>
import pkg from '../package.json'
</script>
