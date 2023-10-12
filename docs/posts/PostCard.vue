<template>
  <a :href="post.url">
    {{ post }}
    <br>
  </a>
</template>

<script lang="ts">
import {defineComponent, PropType} from "vue";

interface Post {
  url: string,
  frontmatter: {
    title: string,
    date: string
  }
}

export default defineComponent({
  props: {
    post: {
      required: true,
      type: Object as PropType<Post>
    }
  }
})
</script>

<style scoped>

</style>
