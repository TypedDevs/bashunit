---
aside: false
editLink: false
lastUpdated: false
---

# Blog posts

<PostCard
  v-for="post of pagedPosts"
  :key="post.url"
  :post="post"
/>

<nav
  v-if="totalPages > 1"
  class="blog-pagination"
  aria-label="Blog pagination"
>
  <button
    class="blog-pagination__nav"
    :disabled="page === 1"
    @click="go(page - 1)"
  >
    ‹ Prev
  </button>
  <button
    v-for="n in totalPages"
    :key="n"
    :class="['blog-pagination__page', { 'is-active': n === page }]"
    :aria-current="n === page ? 'page' : undefined"
    @click="go(n)"
  >
    {{ n }}
  </button>
  <button
    class="blog-pagination__nav"
    :disabled="page === totalPages"
    @click="go(page + 1)"
  >
    Next ›
  </button>
</nav>

<script setup>
import { ref, computed } from 'vue'
import { data as posts } from './posts.data.ts'
import PostCard from './PostCard.vue'

const perPage = 10
const page = ref(1)

const totalPages = computed(() => Math.max(1, Math.ceil(posts.length / perPage)))
const pagedPosts = computed(() => {
  const start = (page.value - 1) * perPage
  return posts.slice(start, start + perPage)
})

function go(n) {
  page.value = Math.min(totalPages.value, Math.max(1, n))
  if (typeof window !== 'undefined') {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
}
</script>

<style>
.blog-pagination {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 40px;
}

.blog-pagination__nav,
.blog-pagination__page {
  min-width: 40px;
  padding: 6px 12px;
  border: solid 1px var(--vp-c-divider);
  border-radius: 8px;
  background-color: var(--vp-c-bg-soft);
  color: var(--vp-c-text-1);
  font-size: 14px;
  cursor: pointer;
  transition: all 0.25s;
}

.blog-pagination__nav:hover:not(:disabled),
.blog-pagination__page:hover {
  border-color: var(--vp-c-brand-2);
}

.blog-pagination__nav:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.blog-pagination__page.is-active {
  border-color: var(--vp-c-brand-1);
  background-color: var(--vp-c-brand-1);
  color: var(--vp-c-bg);
  font-weight: 600;
}
</style>
