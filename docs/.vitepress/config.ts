import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "bashunit",
  description: "A simple testing library for bash scripts",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    sidebar: [
      {
        text: 'Examples',
        items: [
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'Assertions', link: '/assertions' }
        ]
      }
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/TypedDevs/bashunit' }
    ]
  }
})
