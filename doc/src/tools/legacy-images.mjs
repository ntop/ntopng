// Sphinx served every image from /_images/<name>: keep those URLs alive. Runs after `vitepress build` (npm postbuild).
import { cpSync, existsSync, mkdirSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'
const SKIP = new Set(['node_modules', 'dist', 'public', '.vitepress', 'tools'])
const walk = (d) => readdirSync(d).flatMap((f) => SKIP.has(f) ? [] : statSync(join(d, f)).isDirectory() ? walk(join(d, f)) : /\.(png|jpe?g|gif|svg)$/i.test(f) ? [join(d, f)] : [])
mkdirSync('dist/_images', { recursive: true })
for (const f of walk('.')) { const to = join('dist/_images', f.split('/').pop()); if (!existsSync(to)) cpSync(f, to) }
