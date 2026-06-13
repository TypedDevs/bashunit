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
    ['meta', { name: 'theme-color', content: '#22c55e' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'bashunit' }],
    ['meta', { property: 'og:image', content: 'https://bashunit.com/og-image.png' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:site', content: '@bashunit' }],
    ['meta', { name: 'twitter:image', content: 'https://bashunit.com/og-image.png' }]
  ],
  transformHead(context) {
    const canonical = context.page.replace(/(index)?\.md$/, '')
    const url = `https://bashunit.com/${canonical}`
    const description = context.description || context.frontmatter?.description ||
      'Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.'

    return [
      ['meta', { property: 'og:title', content: context.title }],
      ['meta', { property: 'og:description', content: description }],
      ['meta', { property: 'og:url', content: url }],
      ['meta', { name: 'twitter:title', content: context.title }],
      ['meta', { name: 'twitter:description', content: description }],
      ['link', { rel: 'canonical', href: url }],
    ]
  },

  sitemap: {
    hostname: 'https://bashunit.com'
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
        text: 'Getting Started',
        collapsed: false,
        items: [
          { text: 'Quickstart', link: '/quickstart' },
          { text: 'Installation', link: '/installation' },
        ],
      }, {
        text: 'Usage',
        collapsed: false,
        items: [
          { text: 'Command line', link: '/command-line' },
          { text: 'Configuration', link: '/configuration' },
          { text: 'Test files', link: '/test-files' },
          { text: 'Globals', link: '/globals' },
        ],
      }, {
        text: 'Writing Tests',
        collapsed: false,
        items: [
          { text: 'Assertions', link: '/assertions' },
          { text: 'Custom asserts', link: '/custom-asserts' },
          { text: 'Data providers', link: '/data-providers' },
          { text: 'Test doubles', link: '/test-doubles' },
          { text: 'Snapshots', link: '/snapshots' },
          { text: 'Skipping/incomplete', link: '/skipping-incomplete' },
        ],
      }, {
        text: 'Advanced',
        collapsed: true,
        items: [
          { text: 'Coverage', link: '/coverage' },
          { text: 'Benchmarks', link: '/benchmarks' },
          { text: 'Standalone', link: '/standalone' },
          { text: 'Common patterns', link: '/common-patterns' },
        ],
      }, {
        text: 'Reference',
        collapsed: true,
        items: [
          { text: 'Examples', link: '/examples' },
          { text: 'Project overview', link: '/project-overview' },
          { text: 'Support', link: '/support' },
        ],
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
      provider: 'local',
      options: {
        _render(src, env, md) {
          const html = md.render(src, env)

          return html.replace(
            /{{\s*\$frontmatter\.(\w+)\s*}}/g,
            (_, key) => env.frontmatter[key]?.toString() || ''
          )
        }
      }
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright:
        'Copyright © 2023-present ' +
        '<a href="https://github.com/TypedDevs/bashunit/graphs/contributors"' +
        ' target="_blank">bashunit contributors</a>'
    }
  },

  srcExclude: [
    'blog/0000-00-00-template.md'
  ],

  markdown: {
    image: {
      // lazy-load + async-decode all markdown images to cut initial page weight
      lazyLoading: true
    }
  }
})
