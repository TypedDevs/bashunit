<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import pkg from '../../../package.json'

const year = new Date().getFullYear()

const links = [
  { text: 'Docs', link: '/quickstart' },
  { text: 'Blog', link: '/blog/' },
  { text: 'Changelog', link: 'https://github.com/TypedDevs/bashunit/blob/main/CHANGELOG.md' },
  { text: 'Contributing', link: 'https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md' },
  { text: 'Support', link: '/support' },
]

const showTop = ref(false)
let lastY = 0

function onScroll() {
  const y = window.scrollY
  showTop.value = y < lastY && y > 400
  lastY = y
}

onMounted(() => {
  lastY = window.scrollY
  window.addEventListener('scroll', onScroll, { passive: true })
})

onUnmounted(() => {
  window.removeEventListener('scroll', onScroll)
})

function scrollTop() {
  window.scrollTo({ top: 0, behavior: 'smooth' })
}
</script>

<template>
  <footer class="bu-footer">
    <div class="bu-footer-inner">
      <nav class="bu-footer-links" aria-label="Footer">
        <a
          v-for="item in links"
          :key="item.text"
          :href="item.link"
          :target="item.link.startsWith('http') ? '_blank' : undefined"
        >{{ item.text }}</a>
      </nav>

      <div class="bu-footer-bar">
        <span>© 2023–{{ year }} bashunit</span>
        <span class="bu-footer-dot">•</span>
        <span class="bu-footer-meta">Bash 3.0+ Required • v{{ pkg.version }}</span>
      </div>
    </div>

    <Transition name="bu-top-fade">
      <button
        v-show="showTop"
        class="bu-top-float"
        type="button"
        aria-label="Scroll to top"
        @click="scrollTop"
      >↑</button>
    </Transition>
  </footer>
</template>

<style scoped>
.bu-footer {
  border-top: 1px solid var(--vp-c-divider);
  background-color: var(--vp-c-bg-alt);
  padding: 32px 24px;
}

.bu-footer-inner {
  max-width: 720px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  text-align: center;
}

.bu-footer-links {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 8px 24px;
}

.bu-footer-links a {
  font-size: 14px;
  color: var(--vp-c-text-2);
  text-decoration: none;
  transition: color 0.25s;
}

.bu-footer-links a:hover {
  color: var(--vp-c-brand-1);
}

.bu-footer-bar {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  align-items: center;
  gap: 8px;
  width: 100%;
  font-size: 12px;
  color: var(--vp-c-text-3);
}

.bu-footer-dot {
  opacity: 0.5;
}

/* Floating scroll-to-top: bottom-right, shown only when scrolling up */
.bu-top-float {
  position: fixed;
  right: 24px;
  bottom: 24px;
  z-index: 40;
  width: 42px;
  height: 42px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 18px;
  line-height: 1;
  border: 1px solid var(--vp-c-divider);
  border-radius: 50%;
  background: var(--vp-c-bg);
  color: var(--vp-c-text-2);
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
  transition: border-color 0.25s, color 0.25s, background 0.25s;
}

.bu-top-float:hover {
  border-color: var(--vp-c-brand-1);
  color: var(--vp-c-brand-1);
}

.bu-top-fade-enter-active,
.bu-top-fade-leave-active {
  transition: opacity 0.25s, transform 0.25s;
}

.bu-top-fade-enter-from,
.bu-top-fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
</style>
