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

const posts = data.filter((post) => post.url != '/posts/' && post.url != '/posts/0000-00-00-template')
  .sort((postA, postB) => postA.url < postB.url)
</script>
