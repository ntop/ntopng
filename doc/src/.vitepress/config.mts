import { defineConfig } from 'vitepress'
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import imageFigures from 'markdown-it-image-figures'
import deflist from 'markdown-it-deflist'
import llmstxt from 'vitepress-plugin-llms'

const here = dirname(fileURLToPath(import.meta.url))
const PRODUCTS: Record<string, { site: string, slug: string, repo: string, branch: string, srcPath: string, version: string, desc: string, nav: any[] }> = {
  ntopng: { site: 'ntopng', slug: 'ntopng', repo: 'ntopng', branch: 'dev', srcPath: 'doc/src', version: '7.1.261018',
    desc: 'ntopng documentation: installation, configuration, user interface, alerts, flows, historical data, REST API and integrations of the high-speed web-based traffic analysis and flow collection tool.',
    nav: [{ text: "User's Guide", link: '/what_is_ntopng', activeMatch: '^/(?!api|scripts)' }, { text: "Developer's Guide", link: '/api/', activeMatch: '^/(api|scripts)' }] },
}
const DOC = 'ntopng'
const P = PRODUCTS[DOC]
const nav = JSON.parse(readFileSync(resolve(here, `nav.json`), 'utf8'))
const HOST = 'https://www.ntop.org'
const BASE = `/guides/${P.slug}/`
const SITE = P.site
const VERSION = P.version
const TITLE = `${SITE} User's Guide`
const DESCRIPTION = P.desc

const other = [
  ['ntopng', '/guides/ntopng/'], ['nEdge', '/guides/nedge/'],
  ['nProbe', '/guides/nprobe/'], ['nProbe Cento', '/guides/cento/'], ['n2disk', '/guides/n2disk/'],
  ['nDPI', '/guides/nDPI/'], ['PF_RING', '/guides/pf_ring/'], ['nEdge Lite', '/guides/nedgelite/'],
  ['nScrub', '/guides/nscrub/'], ['nBox', '/guides/nbox/'], ['nTap', '/guides/ntap/'],
  ['License Manager', '/guides/license/'],
]

// every ntop guide at the bottom of each sidebar (other products live under another base: full URLs)
const sidebar = [...nav.sidebar, { text: 'All ntop guides', collapsed: false, items: other.map(([text, link]) => ({ text, link: HOST + link })) }]

export default defineConfig({
  lang: 'en-US',
  title: TITLE,
  titleTemplate: `:title | ${TITLE}`,
  description: DESCRIPTION,
  base: BASE,
  outDir: 'dist',
  cleanUrls: false,
  lastUpdated: true,
  ignoreDeadLinks: [/^https?:\/\/localhost/],
  srcExclude: ['README.md', 'node_modules/**', 'dist/**', 'tools/**'],
  sitemap: { hostname: `${HOST}${BASE}` },
  markdown: {
    config: (md) => { md.use(deflist); md.use(imageFigures, { figcaption: 'title', lazy: true, async: true }) },
  },
  vite: { plugins: [llmstxt({ domain: `${HOST}${BASE}` }) as any] },
  head: [
    // light by default: the visitor's choice (theme toggle) is kept in localStorage and wins over the system setting
    ['script', {}, "try{if(!localStorage.getItem('vitepress-theme-appearance'))localStorage.setItem('vitepress-theme-appearance','light')}catch(e){}"],
    ['link', { rel: 'icon', href: `${BASE}logo.png` }],
    ['meta', { name: 'theme-color', content: '#0f6bbd' }],
    ['meta', { name: 'author', content: 'ntop.org' }],
    ['meta', { property: 'og:site_name', content: TITLE }],
    ['meta', { property: 'og:type', content: 'article' }],
    ['meta', { property: 'og:image', content: `${HOST}${BASE}logo.png` }],
    ['meta', { name: 'twitter:card', content: 'summary' }],
    ['meta', { name: 'twitter:site', content: '@ntop_org' }],
  ],
  transformHead({ pageData }) {
    const path = pageData.relativePath.replace(/\.md$/, '.html')
    const url = `${HOST}${BASE}${path}`
    const title = pageData.frontmatter.title || pageData.title
    const desc = pageData.frontmatter.description || DESCRIPTION
    const crumbs = path.split('/').slice(0, -1).map((seg, i, a) => ({
      '@type': 'ListItem', position: i + 2, name: seg.replace(/_/g, ' '),
      item: `${HOST}${BASE}${a.slice(0, i + 1).join('/')}/index.html`,
    }))
    const ld = {
      '@context': 'https://schema.org',
      '@graph': [
        {
          '@type': 'TechArticle', headline: title, description: desc, url, inLanguage: 'en',
          dateModified: pageData.lastUpdated ? new Date(pageData.lastUpdated).toISOString() : undefined,
          publisher: { '@type': 'Organization', name: 'ntop', url: 'https://www.ntop.org', logo: { '@type': 'ImageObject', url: `${HOST}${BASE}logo.png` } },
          isPartOf: { '@type': 'WebSite', name: TITLE, url: `${HOST}${BASE}` },
        },
        { '@type': 'BreadcrumbList', itemListElement: [{ '@type': 'ListItem', position: 1, name: SITE, item: `${HOST}${BASE}index.html` }, ...crumbs] },
      ],
    }
    return [
      ['link', { rel: 'canonical', href: url }],
      ['meta', { property: 'og:title', content: `${title} | ${TITLE}` }],
      ['meta', { property: 'og:description', content: desc }],
      ['meta', { property: 'og:url', content: url }],
      ['meta', { name: 'twitter:title', content: `${title} | ${TITLE}` }],
      ['meta', { name: 'twitter:description', content: desc }],
      ['script', { type: 'application/ld+json' }, JSON.stringify(ld)],
    ]
  },
  themeConfig: {
    logo: { src: '/logo.png', alt: 'ntop' },
    siteTitle: SITE,
    nav: [
      ...P.nav.filter((item) => item.text !== "User's Guide"),
      { text: 'ntop Guides', items: other.filter(([, l]) => l !== BASE).map(([text, link]) => ({ text, link: HOST + link })) },
    ],
    sidebar,
    search: {
      provider: 'local',
      options: { detailedView: true, miniSearch: { searchOptions: { boost: { title: 4, text: 1 }, fuzzy: 0.2, prefix: true } } },
    },
    editLink: { pattern: `https://github.com/ntop/${P.repo}/edit/${P.branch}/${P.srcPath}/:path`, text: 'Suggest a change on GitHub' },
    socialLinks: [{ icon: 'github', link: `https://github.com/ntop/${P.repo}` }],
    outline: { level: [2, 3], label: 'On this page' },
    docFooter: { prev: 'Previous', next: 'Next' },
    footer: { message: 'Documentation of the ntop open source tools.', copyright: `Copyright © 2013-2026 ntop` },
  },
})
