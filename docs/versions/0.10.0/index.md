---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: bashunit
  text: v0.10.0
  tagline: Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.
  image:
    src: /logo.svg
    alt: bashunit
  actions:
    - theme: brand
      text: Quickstart
      link: /0.10.0/quickstart
    - theme: alt
      text: Assertions
      link: /0.10.0/assertions
    - theme: alt
      text: Blog
      link: /blog/

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

<ProductHuntBanner />

<h2 class="home__award-title">Honors & Awards</h2>

<div class="home__award-container">
  <a
    href="https://twitter.com/getmanfred/status/1737191954289487900"
    target="_blank"
  >
    <img
      src="/awards/manfred-2023.jpg"
      alt="The Manfred Awards 2023 - bashunit - Side Project of the Year"
    />
  </a>
</div>

<script setup lang="ts">
import { onMounted } from 'vue';
import VanillaTilt from 'vanilla-tilt';
import ProductHuntBanner from "./ProductHuntBanner.vue";

onMounted(() => {
  const heroImage = document.querySelector('.VPHero .VPImage');

  VanillaTilt.init(heroImage, {
    'full-page-listening': true,
    reverse: true,
    gyroscope: false
  });
});
</script>

<style scoped>
.home__award-title {
  text-align: center;
  margin: 4rem 0;
  font-size: 2.75rem;
}

.home__award-container {
  display: grid;
  justify-content: center;
}
</style>
