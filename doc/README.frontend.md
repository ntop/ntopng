# Frontend Build — Quick Reference

## TL;DR

- Frontend source (`http_src/`, `assets/`, `package.json`) now lives in `pro/`.
- `httpdocs/` and `httpdocs/dist/` (compiled output) stay at repo root, unchanged.
- Still run all `npm` commands from **repo root** — they proxy into `pro/` automatically.
- Community-only checkouts (no `pro/`) cannot build the frontend — they just ship the prebuilt `httpdocs/dist/`.

---

## Commands (run from repo root)

```bash
npm install        # once, or after package.json changes
npm run build      # full production build -> httpdocs/dist/
npm run build:dev  # full dev build (unminified, sourcemaps)
npm run watch      # rebuilds ntopng.js on save (Vue app only)
npm run js:lint    # eslint on pro/http_src
npm run css:lint   # stylelint on pro/http_src
```

Requires `pro/` checked out. Node.js ≥ 18.15.0.

---

## Where things live now

| Thing | Path |
|---|---|
| Vue components / JS source | `pro/http_src/` |
| Images, third-party JS/CSS, login script | `pro/assets/` |
| `package.json`, lockfile | `pro/` |
| Build scripts | `pro/build.mjs`, `pro/vite.ntopng.config.js` |
| Lint configs | `pro/.eslintrc.json`, `pro/.stylelintrc` |
| Compiled output (commit this) | `httpdocs/dist/` (repo root, unchanged) |
| Root `package.json` | thin proxy — just `cd pro && npm run <script>` |

---

## Daily workflow

1. Edit files under `pro/http_src/` or `pro/assets/`
2. `npm run watch` (from root) — rebuilds `ntopng.js` + `ntopng.css` on save
3. First time in a session, run `npm run build` once (produces `third-party.js`, themes, images, `login.js` — watch mode preserves these after)
4. Commit `httpdocs/dist/` changes alongside your source changes

---

## `make dist` / `create_dist.sh`

- `make dist` (root Makefile): builds from `pro/` if present, else prints a message and does nothing.
- `create_dist.sh`: same — `cd pro && npm run build`, then commits/pushes `httpdocs/dist`.
- Both **fail silently for community-only devs** — that's intentional, they never had frontend source anyway.

---

## History note

`http_src`/`assets`/`package.json` history was moved out of the community repo into `pro`'s own git history (not just relocated — full commit history preserved on the `pro` side, removed entirely from community).

Next: `git add -A && git commit` in both repos, then push `pro` (community push is on you too).
