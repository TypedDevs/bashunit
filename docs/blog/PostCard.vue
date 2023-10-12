<template>
  <a
    class="post-card__card"
    :href="post.url"
  >
    <h2 class="post-card__title">
      {{ post.frontmatter.title }}
    </h2>
    <time class="post-card__date">
      {{ $formatDate(post.frontmatter.date) }}
    </time>
    <img
      class="post-card__image"
      :src="post.frontmatter.coverUrl"
      :alt="post.frontmatter.coverAlt"
      loading="lazy"
    >
    <p class="post-card__description">
      {{ post.frontmatter.description }}
    </p>
    <span class="post-card__link">
      read more...
    </span>
  </a>
</template>

<script lang="ts">
import { defineComponent, PropType } from 'vue';

interface Post {
  url: string,
  frontmatter: {
    date: string,
    title: string,
    description: string,
    coverUrl: string,
    coverAlt: string,
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

<style scoped lang="css">
.post-card__card {
  display: grid;
  grid-template-areas:
    "title"
    "date"
    "image"
    "description"
    "link";
  gap: 8px 16px;
  padding: 16px;
  background-color: var(--vp-c-bg-soft);
  transition: all 0.25s;
  border-radius: 8px;
  margin-top: 32px;
  overflow: hidden;
  border: solid 1px transparent;
  text-decoration: none;
}

@media (min-width: 768px) {
  .post-card__card {
    grid-template-areas:
    "title  title"
    "date   date"
    "image  description"
    "image  link";
    grid-template-columns: 3fr 4fr;
    grid-template-rows: auto auto 1fr auto;
  }
}

.post-card__card:hover,
.post-card__card:focus {
  border-color: var(--vp-c-brand-2);
}

.post-card__title {
  grid-area: title;
  border: none;
  margin: 0;
  padding: 0;
}

.post-card__date {
  grid-area: date;
  color: var(--vp-c-text-1);
  opacity: 0.8;
  font-size: 14px;
}

.post-card__image {
  grid-area: image;
  background-color: var(--vp-c-bg);
}

.post-card__description {
  grid-area: description;
  color: var(--vp-c-text-1);
  padding: 0;
  margin: 0;
}

.post-card__link {
  grid-area: link;
  text-align: right;
}
</style>
