---
# https://vitepress.dev/reference/default-theme-home-page
layout: home
description: "bashunit is a fast, simple bash testing framework: assertions, mocks, spies, data providers, snapshots and coverage. Runs on Bash 3.0+ (Linux, macOS, WSL)."

hero:
  name: bashunit
  text: A simple testing library for bash scripts
  tagline: Write and run tests for your Bash scripts on Bash 3.0 and newer.
  image:
    src: /logo.svg
    alt: bashunit
  actions:
    - theme: brand
      text: Quickstart
      link: /quickstart
    - theme: alt
      text: Assertions
      link: /assertions
    - theme: alt
      text: Blog
      link: /blog/

features:
  - icon:
      src: /flexible.svg
    title: Flexible
    details: Assertions, mocks, spies, data providers and snapshots to check your scripts' output and behavior.
  - icon:
      src: /accessible.svg
    title: Fast and CI-ready
    details: Run in parallel or shard the suite across runners, run only what changed, measure coverage, and publish JUnit, TAP, JSON, HTML or Markdown reports.
  - icon:
      src: /updated.svg
    title: Community
    details: Ask questions, report bugs, suggest features and contribute on GitHub.
  - icon:
      src: /multiplatform.svg
    title: Multiplatform
    details: Run the same tests on Linux, macOS and Windows via WSL.
---

<div class="home-example">

## Test your first Bash function

Install bashunit and create folders for your script and test:

```bash
curl -s https://bashunit.com/install.sh | bash
mkdir -p src tests
```

Save these two files:

::: code-group
```bash [src/greet.sh]
#!/usr/bin/env bash

function greet() {
  printf 'Hello, %s!\n' "${1:-world}"
}
```

```bash [tests/greet_test.sh]
#!/usr/bin/env bash

function set_up() {
  source src/greet.sh
}

function test_greet_by_name() {
  assert_same "Hello, Bash!" "$(greet Bash)"
}
```
:::

Run your test:

```bash
./lib/bashunit tests/
```

A passing run reports:

```text
✓ Passed: Greet by name

Tests:      1 passed, 1 total
Assertions: 1 passed, 1 total
```

Continue with the [Quickstart](/quickstart) for other install methods and running options.

</div>

<style scoped>
.home-example {
  max-width: 760px;
  margin: 64px auto 0;
}
</style>

<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import VanillaTilt, { type HTMLVanillaTiltElement } from 'vanilla-tilt';

let cleanupTilt = () => {};

onMounted(() => {
  const heroImage = document.querySelector<HTMLVanillaTiltElement>('.VPHero .VPImage');
  if (!heroImage) return;

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const updateTilt = () => {
    if (reducedMotion.matches) {
      heroImage.vanillaTilt?.destroy();
      return;
    }

    VanillaTilt.init(heroImage, {
      'full-page-listening': true,
      reverse: true,
      gyroscope: false
    });
  };

  updateTilt();
  reducedMotion.addEventListener('change', updateTilt);
  cleanupTilt = () => {
    reducedMotion.removeEventListener('change', updateTilt);
    heroImage.vanillaTilt?.destroy();
  };
});

onUnmounted(() => cleanupTilt());
</script>
