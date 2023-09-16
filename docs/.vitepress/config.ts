import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'bashunit - A simple testing library for bash scripts',
  titleTemplate: 'bashunit',
  description: 'Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.',
  lang: 'en-US',

  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }]
  ],

  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    logo: '/logo.svg',

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
    ],

    search: {
      provider: 'local'
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2023-present TypedDevs'
    }
  }
})
