import { defineConfig } from 'vitepress'
import pkg from '../../package.json'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'bashunit - A simple testing library for bash scripts',
  titleTemplate: 'bashunit',
  description: 'Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.',
  lang: 'en-US',
  cleanUrls: true,

  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }]
  ],

  sitemap: {
    hostname: 'https://bashunit.typeddevs.com'
  },

  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    externalLinkIcon: true,
    siteTitle: false,

    logo: {
      light: '/logo_navbar.svg',
      dark: '/logo_navbar_dark.svg',
      alt: 'bashunit'
    },

    sidebar: [{
      items: [{
        text: 'Getting Started',
        link: '/getting-started',
        items: [{
          text: 'Installation',
          link: '/getting-started#installation',
        }, {
          text: 'Usage',
          link: '/getting-started#usage',
        }]
      }, {
        text: 'Test files',
        link: '/test-files',
        items: [{
          text: 'Test file names',
          link: '/test-files#test-file-names',
        }, {
          text: 'Test function names',
          link: '/test-files#test-function-names',
        }]
      }, {
        text: 'Test doubles',
        link: '/test-doubles'
      }, {
        text: 'Assertions',
        link: '/assertions'
      }, {
        text: 'Skipping/incomplete',
        link: '/skipping-incomplete'
      }, {
        text: 'Examples',
        link: '/examples'
      }]
    }],

    socialLinks: [
      { icon: 'x', link: 'https://x.com/bashunit' },
      { icon: 'github', link: 'https://github.com/TypedDevs/bashunit' }
    ],

    nav: [{
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
      message: 'Released under the MIT License.',
      copyright: 'Copyright © 2023-present TypedDevs'
    }
  }
})
