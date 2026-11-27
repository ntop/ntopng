// Whole-guide PDF from the built site (replaces rst2pdf).  Usage: DOC=ntopng node tools/pdf.mjs
// Requires `npm run build` first. Chrome: $CHROME or /usr/bin/google-chrome.
import { chromium } from 'playwright-core'
import { createServer } from 'node:http'
import { readFileSync, existsSync, statSync, mkdirSync } from 'node:fs'
import { extname, join, resolve } from 'node:path'

const DOC = 'ntopng'
const root = resolve('dist')
const nav = JSON.parse(readFileSync('.vitepress/nav.json', 'utf8'))
const base = `/guides/${DOC}/`
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.json': 'application/json' }

const server = createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]).replace(base, '/')
  let f = join(root, p)
  if (existsSync(f) && statSync(f).isDirectory()) f = join(f, 'index.html')
  if (!existsSync(f)) { res.writeHead(404); return res.end() }
  res.writeHead(200, { 'content-type': mime[extname(f)] || 'application/octet-stream' })
  res.end(readFileSync(f))
}).listen(0)
const origin = `http://localhost:${server.address().port}${base}`

// page order = sidebar order
const order = []
const walk = (items) => items.forEach((i) => { if (i.link && !i.link.startsWith('http')) order.push(i.link === '/' ? 'index.html' : i.link.replace(/^\//, '').replace(/\/$/, '/index') + (i.link.endsWith('.html') ? '' : '.html')); if (i.items) walk(i.items) })
walk(nav.sidebar)
const pages = [...new Set(order.map((o) => o.replace(/\.html\.html$/, '.html')))].filter((p) => existsSync(join(root, p)))

const browser = await chromium.launch({ executablePath: process.env.CHROME || '/usr/bin/google-chrome', args: ['--no-sandbox'] })
const ctx = await browser.newContext()
const page = await ctx.newPage()
let css = ''
const parts = []
for (const [n, p] of pages.entries()) {
  await page.goto(origin + p, { waitUntil: 'networkidle' })
  if (!css) css = await page.evaluate(() => [...document.querySelectorAll('link[rel=stylesheet]')].map((l) => l.href).join('\n'))
  const html = await page.evaluate(() => {
    const d = document.querySelector('.vp-doc')
    d.querySelectorAll('img').forEach((i) => { i.loading = 'eager'; i.src = i.src })
    d.querySelectorAll('a.header-anchor').forEach((a) => a.remove())
    return d.innerHTML
  })
  parts.push(`<section class="chapter" id="${p.replace(/\W/g, '_')}">${html}</section>`)
  if (n % 25 === 0) console.log(`${n}/${pages.length}`)
}
const links = css.split('\n').filter(Boolean).map((h) => `<link rel="stylesheet" href="${h}">`).join('')
const NAMES = { ntopng: 'ntopng', nedge: 'nEdge', n2disk: 'n2disk', nprobe: 'nProbe', cento: 'nProbe Cento', nscrub: 'nScrub', nDPI: 'nDPI' }
const title = `${NAMES[DOC]} User's Guide`
const doc = `<!doctype html><html class="print"><head><meta charset="utf-8"><title>${title}</title>${links}
<style>
body{background:#fff;color:#000} .chapter{page-break-before:always} .cover{height:90vh;display:flex;flex-direction:column;justify-content:center;align-items:center;text-align:center}
.vp-doc{max-width:none;padding:0} img{max-width:100%;max-height:245mm;width:auto;height:auto;object-fit:contain;page-break-inside:avoid} pre{white-space:pre-wrap}
</style></head><body><div class="cover"><img src="${origin}logo.png" style="width:160px;border:0"><h1>${title}</h1><p>ntop.org</p></div>
${parts.map((x) => `<div class="vp-doc">${x}</div>`).join('')}</body></html>`
await page.setContent(doc, { waitUntil: 'networkidle', timeout: 600000 })
mkdirSync('dist/pdf', { recursive: true })
const out = `dist/pdf/${DOC}-users-guide.pdf`
await page.pdf({ path: out, format: 'A4', printBackground: true, margin: { top: '18mm', bottom: '18mm', left: '15mm', right: '15mm' }, displayHeaderFooter: true,
  headerTemplate: `<div style="font-size:8px;width:100%;text-align:center;color:#666">${title}</div>`,
  footerTemplate: '<div style="font-size:8px;width:100%;text-align:center;color:#666"><span class="pageNumber"></span> / <span class="totalPages"></span></div>' })
console.log('PDF:', out, pages.length, 'pages')
await browser.close(); server.close()
