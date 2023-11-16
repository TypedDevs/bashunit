---
aside: false
editLink: false
lastUpdated: false
---

# Blog posts

<PostCard
  v-for="post of posts"
  :key="post.url"
  :post="post"
/>

<script setup>
import { data } from './posts.data.ts'
import PostCard from './PostCard.vue'

const posts = data.filter((post) => post.url != '/blog/' && post.url != '/blog/0000-00-00-template')
  .sort((postA, postB) => postA.url < postB.url)
</script>
