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
import { data as posts } from './posts.data.ts'
import PostCard from './PostCard.vue'
</script>
