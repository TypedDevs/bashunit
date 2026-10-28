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

<script setup lang="ts">
import { onMounted } from 'vue';
import VanillaTilt from 'vanilla-tilt';

onMounted(() => {
  const heroImage = document.querySelector('.VPHero .VPImage');

  VanillaTilt.init(heroImage, {
    'full-page-listening': true,
    reverse: true,
    gyroscope: false
  });
});
</script>
