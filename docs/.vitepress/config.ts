import { defineConfig } from 'vitepress'
import fs from 'node:fs'
import path from 'node:path'
import pkg from '../../package.json'

// Order of pages concatenated into llms-full.txt (full docs for LLM/agent consumption).
const LLMS_ORDER = [
  'quickstart', 'installation', 'project-overview',
  'assertions', 'custom-asserts', 'test-doubles', 'data-providers', 'snapshots',
  'skipping-incomplete', 'test-files', 'globals', 'common-patterns',
  'command-line', 'configuration', 'coverage', 'benchmarks', 'standalone',
  'ai-agents', 'examples', 'support'
]

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
    // Discoverability for agents: the docs are also published as plain text.
    ['link', { rel: 'alternate', type: 'text/plain', href: 'https://bashunit.com/llms.txt', title: 'llms.txt' }],
    ['meta', { name: 'theme-color', content: '#22c55e' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'bashunit' }],
    ['meta', { property: 'og:image', content: 'https://bashunit.com/og-image.png' }],
    ['meta', { property: 'og:image:width', content: '1200' }],
    ['meta', { property: 'og:image:height', content: '630' }],
    ['meta', { property: 'og:image:alt', content: 'bashunit — a simple testing library for bash scripts' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:site', content: '@bashunit' }],
    ['meta', { name: 'twitter:image', content: 'https://bashunit.com/og-image.png' }],
    ['meta', { name: 'twitter:image:alt', content: 'bashunit — a simple testing library for bash scripts' }]
  ],
  transformHead(context) {
    const canonical = context.page.replace(/(index)?\.md$/, '')
    const url = `https://bashunit.com/${canonical}`
    const description = context.description || context.frontmatter?.description ||
      'Test your bash scripts in the fastest and simplest way, discover the most modern bash testing library.'

    const isHome = context.page === 'index.md'
    const jsonLd = isHome
      ? {
        '@context': 'https://schema.org',
        '@type': 'SoftwareApplication',
        name: 'bashunit',
        applicationCategory: 'DeveloperApplication',
        operatingSystem: 'Linux, macOS, Windows (WSL)',
        softwareVersion: pkg.version,
        url: 'https://bashunit.com',
        description,
        license: 'https://opensource.org/licenses/MIT',
        offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' }
      }
      : {
        '@context': 'https://schema.org',
        '@type': 'TechArticle',
        headline: context.title,
        description,
        url,
        isPartOf: { '@type': 'WebSite', name: 'bashunit', url: 'https://bashunit.com' }
      }

    return [
      ['meta', { property: 'og:title', content: context.title }],
      ['meta', { property: 'og:description', content: description }],
      ['meta', { property: 'og:url', content: url }],
      ['meta', { name: 'twitter:title', content: context.title }],
      ['meta', { name: 'twitter:description', content: description }],
      ['link', { rel: 'canonical', href: url }],
      ['script', { type: 'application/ld+json' }, JSON.stringify(jsonLd)],
    ]
  },

  sitemap: {
    hostname: 'https://bashunit.com',
    // lastmod drives Google's recrawl scheduling, but only while it stays
    // verifiably accurate. Git mtime lies twice here: a repo-wide touch-up
    // re-stamps years-old announcements as fresh (five 2024 posts all claimed
    // 2026-06-03), and /blog/ never moves even though its listing is rebuilt
    // from posts.data.ts on every new post.
    transformItems(items) {
      const publishedAt = (url: string) => url.match(/^blog\/(\d{4}-\d{2}-\d{2})-/)?.[1]
      const newestPost = items
        .map((item) => publishedAt(item.url))
        .filter((date): date is string => !!date)
        .sort()
        .pop()

      return items.map((item) => {
        const date = item.url === 'blog/' ? newestPost : publishedAt(item.url)
        return date ? { ...item, lastmod: new Date(`${date}T00:00:00Z`) } : item
      })
    }
  },

  // Generate /llms-full.txt: the full documentation concatenated for LLMs and agents.
  buildEnd(siteConfig) {
    let out = '# bashunit — full documentation\n\n'
    out += '> Full text of the bashunit docs, concatenated for LLMs and agents.'
    out += ' Source: https://bashunit.com — see also https://bashunit.com/llms.txt\n'
    for (const slug of LLMS_ORDER) {
      const file = path.join(siteConfig.srcDir, `${slug}.md`)
      if (!fs.existsSync(file)) continue
      const md = fs.readFileSync(file, 'utf-8').replace(/^---\n[\s\S]*?\n---\n/, '').trim()
      out += `\n\n---\n\n<!-- Source: https://bashunit.com/${slug} -->\n\n${md}\n`
    }
    fs.writeFileSync(path.join(siteConfig.outDir, 'llms-full.txt'), out)
  },

  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    externalLinkIcon: true,
    siteTitle: false,

    // Reference pages carry their per-flag and per-pattern detail at H3 (27 of them on
    // command-line, 24 on common-patterns, 23 on coverage). The VitePress default of
    // H2-only hides exactly the headings people navigate to. Must live under
    // themeConfig: the outline is read as `frontmatter.outline ?? theme.outline`,
    // so a top-level `outline` is silently ignored.
    outline: [2, 3],

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
          { text: 'Agentic coding', link: '/ai-agents' },
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
    }
  },

  srcExclude: [
    'blog/0000-00-00-template.md',
    // public/ is copied verbatim as static assets; without this, any .md in it is
    // ALSO rendered as a page (/public/<name>) and lands in the sitemap.
    'public/**/*.md'
  ],

  markdown: {
    image: {
      // lazy-load + async-decode all markdown images to cut initial page weight
      lazyLoading: true
    }
  }
})
