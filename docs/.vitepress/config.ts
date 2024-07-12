import { defineConfig } from 'vitepress'
import pkg from '../../package.json'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'bashunit - A simple testing library for bash scripts',
  titleTemplate: 'bashunit',
  description: 'Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.',
  lang: 'en-US',
  cleanUrls: true,
  lastUpdated: true,

  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:image', content: '/og-image.png' }]
  ],
  transformHead(context) {
    const canonical = context.page.replace(/(index)?\.md$/, '')

    return [
      ['meta', { property: 'og:title', content: context.title }],
      ['meta', { property: 'og:url', content: `https://bashunit.typeddevs.com/${canonical}` }],
      ['link', { rel: 'canonical', href: `https://bashunit.typeddevs.com/${canonical}` }],
    ]
  },

  sitemap: {
    hostname: 'https://bashunit.typeddevs.com'
  },

  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    externalLinkIcon: true,
    siteTitle: false,

    editLink: {
      pattern: 'https://github.com/TypedDevs/bashunit/edit/main/docs/:path'
    },

    logo: {
      light: '/logo-navbar.svg',
      dark: '/logo-navbar-dark.svg',
      alt: 'bashunit'
    },

    sidebar: {
      '/': [{
        text: 'Quickstart',
        link: '/quickstart',
      }, {
        text: 'Installation',
        link: '/installation',
      }, {
        text: 'Command line',
        link: '/command-line'
      }, {
        text: 'Configuration',
        link: '/configuration'
      }, {
        text: 'Test files',
        link: '/test-files',
      }, {
        text: 'Parameterized tests',
        link: '/parameterized-tests',
      }, {
        text: 'Test doubles',
        link: '/test-doubles'
      }, {
        text: 'Assertions',
        link: '/assertions'
      }, {
        text: 'Snapshots',
        link: '/snapshots'
      }, {
        text: 'Skipping/incomplete',
        link: '/skipping-incomplete'
      }, {
        text: 'Standalone',
        link: '/standalone'
      }, {
        text: 'Custom asserts',
        link: '/custom-asserts'
      }, {
        text: 'Examples',
        link: '/examples'
      }, {
        text: 'Support',
        link: '/support',
      }],
      '/blog/': []
    },

    socialLinks: [
      { icon: 'x', link: 'https://x.com/bashunit' },
      { icon: 'github', link: 'https://github.com/TypedDevs/bashunit' }
    ],

    nav: [{
      text: 'Docs',
      link: '/quickstart',
      activeMatch: '^/(?!blog)[^/]'
    }, {
      text: 'Blog',
      link: '/blog/',
      activeMatch: '^/blog/'
    }, {
      text: pkg.version,
      items: [
        {
          text: 'Changelog',
          link: 'https://github.com/TypedDevs/bashunit/blob/main/CHANGELOG.md'
        },
        {
          text: 'Contributing',
          link: 'https://github.com/TypedDevs/bashunit/blob/main/.github/CONTRIBUTING.md'
        }
      ]
    }],

    search: {
      provider: 'local'
    },

    footer: {
      message: 'Released with ❤️ under the MIT License.',
      copyright: `
  Copyright © 2023-present
  <a class="typeddevs-link" href="https://typeddevs.com/" target="_blank">
    <img class="typeddevs-logo" src="/typeddevs.svg">
    TypedDevs
  </a>
`
    }
  },

  srcExclude: [
    'blog/0000-00-00-template.md'
  ]
})
