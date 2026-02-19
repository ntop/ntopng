# Frontend Development (Javascript/Vue/CSS)

The ntopng frontend is compiled with **Vite**. All source lives in `http_src/` and `assets/`;
the compiled output goes to `httpdocs/dist/` and must be committed alongside code changes.

---

## 1. Prerequisites

Node.js **≥ 18.15.0** is required.

---

## 2. Install dependencies

Run once after cloning (or after `package.json` changes):

```bash
npm install
```

---

## 3. Daily development, watch mode

Rebuilds `ntopng.js` automatically on every file save under `http_src/`:

```bash
npm run watch
```

Watch mode rebuilds only the Vue app bundle (`ntopng.js` + `ntopng.css`). Run
`npm run build` once first to produce `third-party.js`, CSS themes, images, and
`login.js` — watch mode then preserves those files between rebuilds.

---

## 4. Build commands

| Command | When to use |
|---|---|
| `npm run build` | Full production build (JS + CSS + assets, minified) |
| `npm run build:dev` | Full development build (unminified, with sourcemaps) |
| `npm run build:ntopngjs` | Rebuild `ntopng.js` only (fast, preserves rest of dist) |

All commands output to `httpdocs/dist/`. **Commit the dist output** before opening a pull request.

---

## 5. What gets built

`npm run build` / `npm run build:dev` runs `build.mjs` which executes five sequential
Vite passes, each producing a self-contained IIFE:

| Output file | Source |
|---|---|
| `third-party.js` + `third-party.css` | `assets/third-party.js` (jQuery, Bootstrap, DataTables, …) |
| `ntopng.js` + `ntopng.css` | `http_src/ntopng.js` (Vue app + SCSS) |
| `dark-mode.css` / `white-mode.css` / `custom-theme.css` | Theme SCSS files |
| `images/flags.png`, `images/blank.gif`, etc. | `assets/images/images.js` |
| `login.js` | `assets/scripts/login.js` (particle animation) |

All bundles are plain IIFEs loaded as `type="application/javascript"` (classic blocking
scripts). `third-party.js` must load first — it sets `window.$`, `window.moment`, and
other globals that `ntopng.js` depends on.

---

## 6. Linting

```bash
npm run css:lint   # SCSS linting (stylelint)
npm run js:lint    # JS linting (eslint)
```
