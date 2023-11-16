import { createContentLoader } from 'vitepress'

export default createContentLoader('blog/*.md', {
  transform(posts){
    return posts
      .filter((post) => post.url != '/blog/' && post.url != '/blog/0000-00-00-template')
      .sort((postA, postB) => postA.url < postB.url ? 1 : -1)
  }
})
