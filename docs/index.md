---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: bashunit
  text: A simple testing library for bash scripts
  tagline: Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.
  image:
    src: /logo.svg
    alt: bashunit
  actions:
    - theme: brand
      text: Getting Started
      link: /getting-started
    - theme: alt
      text: Assertions
      link: /assertions

features:
  - icon:
      src: /flexible.svg
    title: Flexible
    details: Robust assertions for comparing, matching, and validating results, ensuring thorough testing of your codebase.
  - icon:
      src: /accessible.svg
    title: Accessible
    details: An intuitive API and clear documentation for a smooth developer experience, reducing testing complexity.
  - icon:
      src: /updated.svg
    title: Updated
    details: A vibrant GitHub community for support, collaboration, and continuous library enhancement. Join forces with like-minded developers.
  - icon:
      src: /multiplatform.svg
    title: Multiplatform
    details: Seamlessly operates on Linux, macOS, and Windows (via WSL), facilitating a consistent testing environment across major platforms.
---

<script setup lang="ts" type="module">
import VanillaTilt from 'vanilla-tilt';

const heroImage = document.querySelector('.VPHero .VPImage');

VanillaTilt.init(heroImage, {
  'full-page-listening': true,
  reverse: true
});
</script>
