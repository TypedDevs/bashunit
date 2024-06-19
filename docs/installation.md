# Installation

Although there's no Bash script dependency manager like npm for JavaScript, Maven for Java, pip for Python, or composer for PHP;
you can add **bashunit** as a dependency in your repository according to your preferences.

Here, we provide different options that you can use to install **bashunit** in your application.

## install.sh

There is a tool that will generate an executable with the whole library in a single file:

```bash
curl -s https://bashunit.typeddevs.com/install.sh | bash
```

This will create a file inside a lib folder, such as `lib/bashunit`.

#### Define custom tag and folder

The installation script can receive two optional arguments:

```bash
curl -s https://bashunit.typeddevs.com/install.sh | bash -s [dir] [version]
```
- `[dir]`: the destiny directory to save the executable bashunit; `lib` by default
- `[version]`: the [release](https://github.com/TypedDevs/bashunit/releases) to download, for instance `{{ pkg.version }}`; `latest` by default

::: tip
You can use `beta` as `[version]` to get the next non-stable preview release.
We try to keep it stable, but there is no promise that we won't change functions or their signatures without prior notice.
:::

::: tip
Committing (or not) this file to your project it's up to you. In the end, it is a dev dependency.
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
        run: "curl -s https://bashunit.typeddevs.com/install.sh"

      - name: "Test"
        run: "./bashunit tests/**/*_test.sh"
```

::: tip
Check the pipelines running on bashunit itself: https://github.com/TypedDevs/bashunit/blob/main/.github/workflows/tests.yml
:::

## Brew

You can install **bashunit** globally in your macOS (or Linux) using brew.

```bash
brew install bashunit
```

## MacPorts

On macOS, you can also install **bashunit** via [MacPorts](https://www.macports.org):

```bash
sudo port install bashunit
```

<script setup>
import pkg from '../package.json'
</script>
