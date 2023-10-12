---
aside: false
---

# Blog posts

<PostCard
  v-for="post of posts"
  :post="post"
/>

<script setup>
import { data } from './posts.data.ts'
import PostCard from './PostCard.vue'

const posts = data.filter((post) => post.url != '/posts/')
  .sort((postA, postB) => postA.url < postB.url)
</script>
