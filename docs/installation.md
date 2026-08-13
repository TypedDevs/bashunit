---
description: "Install bashunit via install.sh, npm, Brew, MacPorts or bashdep: a single-file bash testing framework running on Bash 3.0+ (Linux, macOS, WSL)."
---

# Installation

**bashunit** ships as a single-file executable. Pick the option that fits your project: `install.sh` (universal), [npm](#npm) (Node.js projects), [Brew](#brew) (macOS/Linux global), [MacPorts](#macports), [Nix](#nix), or [bashdep](#bashdep).

## Requirements

bashunit requires **Bash 3.0** or newer.

On Windows, install [WSL](https://learn.microsoft.com/windows/wsl/install) (`wsl --install`
from an elevated PowerShell, then reboot) and run every command below inside the WSL shell.

Everything else is optional, but some features need it:

| Tool | Needed for | Without it |
|------|------------|------------|
| `jq` | [JSON assertions](/assertions#assert-json-key-exists) | the test is **skipped**, not failed |
| `git` | `--changed`, `--coverage-diff`, `upgrade`, failure diffs | those flags error out; diffs print plain values |
| `inotifywait` (Linux) / `fswatch` (macOS) | [`watch`](/command-line#watch) | falls back to polling |

## install.sh

There is a tool that will generate an executable with the whole library in a single file:

::: code-group
```bash [Linux/Mac]
curl -s https://bashunit.com/install.sh | bash
```

:::

This will create a file inside a lib folder, such as `lib/bashunit`.

::: tip Automatic checksum verification
`install.sh` verifies the download against the release `checksum` asset and aborts on a
mismatch, so a tampered or corrupted download never lands. There are three states:

- **unset** (default): verifies, aborts on a mismatch, and only *warns and continues* when
  the checksum asset or a sha256 tool is unavailable
- `BASHUNIT_VERIFY_CHECKSUM=true`: also aborts when verification is impossible
- `BASHUNIT_VERIFY_CHECKSUM=false`: skips verification entirely

The GitHub Action always passes the variable, so `verify-checksum: 'true'` (its default) is
the strict mode. The manual check below is only needed when you skip verification.
:::

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
curl -s https://bashunit.com/install.sh | bash -s [dir] [version]
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
# Install as dev dependency
npm install --save-dev bashunit

# Run via npx (resolves node_modules/.bin/bashunit)
npx bashunit tests/
```

```bash [Global]
# Install on PATH
npm install -g bashunit

# Run directly, no npx needed
bashunit tests/
```

```bash [One-shot]
# No install, runs the latest release
npx bashunit@latest tests/
```
:::

### Per-project: `package.json` script

Only relevant for the per-project install (global and one-shot don't touch `package.json`).
Define a script so contributors and CI share one command:

```json-vue
{
  "scripts": {
    "test": "bashunit tests/"
  },
  "devDependencies": {
    "bashunit": "^{{ pkg.version }}"
  }
}
```

Then run:

```bash
npm test
# or any custom script name
npm run <script-name>
```

::: warning Windows (native) not supported
The npm package declares `"os": ["darwin", "linux"]`, so `npm install bashunit` on native Windows (PowerShell / cmd) fails with `EBADPLATFORM`:

```text
npm error code EBADPLATFORM
npm error notsup Unsupported platform for bashunit@x.y.z: wanted {"os":"darwin,linux"} (current: {"os":"win32"})
```

Fix: install [WSL](https://learn.microsoft.com/windows/wsl/install) and run `npm install --save-dev bashunit` inside the WSL shell. Alternatively use the [`install.sh`](#install-sh) route from WSL.
:::

::: warning
The npm package only ships the prebuilt single-file binary (no `src/` tree). You cannot `source` internals from `node_modules/bashunit/` - use the `bashunit` command. To vendor or extend the framework, use [install.sh](#install-sh) or clone the repository.
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

## Nix

**bashunit** is packaged in [nixpkgs](https://search.nixos.org/packages?query=bashunit),
so no install step is needed to try it:

::: code-group
```bash [One-shot]
# Run without installing anything
nix-shell -p bashunit --run "bashunit tests/"
```

```bash [Flakes]
nix run nixpkgs#bashunit -- tests/
```

```bash [Profile]
# Install for your user
nix profile install nixpkgs#bashunit
```
:::

To pin it for a project, add it to a `shell.nix`:

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [ pkgs.bashunit ];
}
```

::: warning nixpkgs lags the latest release
The nixpkgs version trails this project's releases, and channels lag further still.
Run `nix-shell -p bashunit --run "bashunit --version"` to see what you would get. When
you need a specific version, use [install.sh](#install-sh) with an explicit `[version]`
argument instead — it is unaffected by channel lag.
:::

## bashdep

You can manage your dependencies using [bashdep](https://github.com/Chemaclass/bashdep),
a simple dependency manager for bash.

::: code-group
```bash-vue [Linux/Mac - install-dependencies.sh]
# Ensure bashdep is installed
[ ! -f lib/bashdep ] && {
  mkdir -p lib
  curl -fsSLo lib/bashdep \
    https://github.com/Chemaclass/bashdep/releases/latest/download/bashdep
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
# Run this inside the WSL shell, see Requirements above.

# Ensure bashdep is installed
[ ! -f lib/bashdep ] && {
  mkdir -p lib
  curl -fsSLo lib/bashdep \
    https://github.com/Chemaclass/bashdep/releases/latest/download/bashdep
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
> installed 1, skipped 0, failed 0
```
:::

Installs are idempotent: bashdep records what it fetched in `lib/.bashdep.lock`,
so a second run prints `> bashunit already exists in 'lib', skipping.` and only
re-downloads when you bump the version in the URL.

::: tip Pin bashdep itself for reproducible builds
`releases/latest/download` always fetches the newest bashdep. For byte-identical
installs across machines and CI, swap it for an explicit tag and verify it against
the published checksum:

```bash
curl -fsSLo lib/bashdep \
  https://github.com/Chemaclass/bashdep/releases/download/0.9.0/bashdep
curl -fsSLo checksum \
  https://github.com/Chemaclass/bashdep/releases/download/0.9.0/checksum
( cd lib && shasum -a 256 -c ../checksum ) && chmod +x lib/bashdep
```
:::

## GitHub Actions

The official `TypedDevs/bashunit` action installs the binary in one step.
Pin it to the floating major tag `@v0` to track the latest release within a major,
or to a commit SHA for an immutable, supply-chain-safe install
(keeps static analyzers such as [zizmor](https://github.com/woodruffw/zizmor) happy):

::: code-group
```yaml-vue [via action]
# .github/workflows/bashunit-tests.yml
name: Tests
on: [pull_request, push]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      # @v0 tracks the latest release within the v0 major.
      # For an immutable pin use a commit SHA: TypedDevs/bashunit@<sha> # {{ pkg.version }}
      - uses: TypedDevs/bashunit@v0
        with:
          version: '{{ pkg.version }}' # omit for the version pinned at this ref
          directory: lib               # optional, "lib" by default
          add-to-path: 'true'          # optional, "true" by default
          verify-checksum: 'true'      # optional, "true" by default
          annotations: auto            # optional, "auto" by default ("never" to turn off)
      # add-to-path puts the binary on $PATH, so just call "bashunit":
      - run: bashunit tests
```

```yaml-vue [install + run]
# .github/workflows/bashunit-tests.yml
name: Tests
on: [pull_request, push]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      # Install and run the suite in a single step via the `args` input.
      - uses: TypedDevs/bashunit@v0
        with:
          version: '{{ pkg.version }}'
          args: tests/ --strict
```

```yaml [via install.sh]
# .github/workflows/bashunit-tests.yml
name: Tests
on: [pull_request, push]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: curl -s https://bashunit.com/install.sh | bash
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
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with: { node-version: 22 }
      - run: npm ci
      - run: npx bashunit tests/
```
:::

**Inputs:** `version` (default: the release pinned at this action ref — `@v0` tracks the newest release at the time it was moved; pass `latest` to always take the newest), `directory` (default `lib`), `add-to-path` (default `true`), `verify-checksum` (default `true`), `args` (default empty — when set, runs `bashunit <args>` after installing), `annotations` (default `auto` — GitHub Actions annotations for failing tests; `never` turns them off, `always` forces them).
**Outputs:** `path` (binary path relative to the workspace), `version` (installed version).

`verify-checksum` validates the downloaded binary against the release `checksum`
asset (sha256) and fails the install on any mismatch. Set it to `false` only when
pinning a release published before checksum assets existed.

### Keep the SHA pin fresh automatically

A commit-SHA pin is the most secure, but bumping it by hand is tedious. Let a bot do it
and keep the `# {{ pkg.version }}` comment as the human-readable tracker.

::: code-group
```json [Renovate - renovate.json]
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "matchPackageNames": ["TypedDevs/bashunit"],
      "pinDigests": true
    }
  ]
}
```

```yaml [Dependabot - .github/dependabot.yml]
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```
:::

Renovate updates the pinned SHA and refreshes the trailing `# tag` comment in the same PR.
Dependabot bumps `github-actions` pins on the schedule you set.

Either way you get bashunit updates as routine pull requests — no manual re-pinning or
`curl | bash` bumps to remember. Review the PR, let CI run, merge.

::: tip
See the action's own end-to-end test for a real example, covering `version`, `directory`,
`add-to-path` and `args`:
https://github.com/TypedDevs/bashunit/blob/main/.github/workflows/test-action.yml

bashunit's `tests.yml` runs the in-repo entrypoint instead, so it is not an install example.
:::

## Updating

For the `install.sh`, GitHub Action and bashdep routes, upgrade the binary in place:

```bash
./lib/bashunit upgrade
```

It downloads the newest release over the same file, and prints
`> You are already on latest version` when there is nothing to do.

Package-manager installs update through their own manager instead: `brew upgrade bashunit`,
`sudo port upgrade bashunit`, `npm install --save-dev bashunit@latest`.

## Shell completion

bashunit ships tab-completion scripts for bash and zsh under
[`completions/`](https://github.com/TypedDevs/bashunit/tree/main/completions)
— subcommands, all `test` flags (with value hints like `--jobs auto` and
`--output tap`), and the assertion names after `bashunit assert`.

::: code-group
```bash [bash]
# With bash-completion installed (path may vary by OS):
cp completions/bashunit.bash /usr/local/etc/bash_completion.d/bashunit

# Or source it directly from your ~/.bashrc:
source /path/to/bashunit/completions/bashunit.bash
```
```zsh [zsh]
# Copy into any directory in your $fpath, e.g.:
cp completions/_bashunit /usr/local/share/zsh/site-functions/_bashunit

# then restart zsh (or reinitialize completions):
autoload -Uz compinit && compinit
```
:::

The scripts are kept honest by an anti-drift test in CI: adding a flag to
bashunit without updating the completions fails the build.

## Related

- [Quickstart](/quickstart) - write and run your first test
- [Command line](/command-line) - CLI flags and options
- [Configuration](/configuration) - env vars and config files
- [Project overview](/project-overview) - repo layout and contributor workflow

<script setup>
import pkg from '../package.json'
</script>
