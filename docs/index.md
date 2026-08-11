---
# https://vitepress.dev/reference/default-theme-home-page
layout: home
description: "bashunit is a fast, simple bash testing framework: assertions, mocks, spies, data providers, snapshots and coverage. Runs on Bash 3.0+ (Linux, macOS, WSL)."

hero:
  name: bashunit
  text: A simple testing library for bash scripts
  tagline: Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.
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
    details: 84 assertions plus mocks, spies, data providers and snapshots, for comparing, matching and validating anything your scripts produce.
  - icon:
      src: /accessible.svg
    title: Fast and CI-ready
    details: Run in parallel or shard the suite across runners, run only what changed, measure coverage, and publish JUnit, TAP, JSON, HTML or Markdown reports.
  - icon:
      src: /updated.svg
    title: Community
    details: A vibrant GitHub community for support, collaboration, and continuous library enhancement. Join forces with like-minded developers.
  - icon:
      src: /multiplatform.svg
    title: Multiplatform
    details: Seamlessly operates on Linux, macOS, and Windows (via WSL), facilitating a consistent testing environment across major platforms.
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
