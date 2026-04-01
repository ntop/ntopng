#!/usr/bin/env node
/**
 * Full ntopng frontend build: all JS + CSS + images
 *
 * Usage:
 *   node build.mjs           -> development build (sourcemaps, unminified)
 *   node build.mjs --prod    -> production build (minified, no sourcemaps)
 *
 * Rollup's IIFE format does not support code-splitting, so each entry must be
 * built in its own Vite invocation. This script runs them sequentially, reusing
 * shared plugin/CSS/resolve config to keep things DRY.
 *
 * Build order:
 *   1. third-party.js  — large self-contained IIFE (jQuery, Bootstrap, DataTables etc)
 *   2. ntopng.js       — Vue app IIFE (jQuery/moment external -> from window.$ / window.moment)
 *   3. CSS themes      — dark-mode, white-mode, custom-theme (CSS-only, parallel)
 *   4. images          — flags.png, blank.gif, Leaflet markers (asset copy)
 *   5. login.js        — standalone particle animation IIFE
 */

import { build } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { renameSync, readdirSync, readFileSync, writeFileSync } from 'fs';
import { gzipSync } from 'zlib';
import inject from '@rollup/plugin-inject';
import autoprefixer from 'autoprefixer';
import sharp from 'sharp';

const __dirname = dirname(fileURLToPath(import.meta.url));
const isProd = process.argv.includes('--prod');

/** Shared SCSS / PostCSS options */
const sharedCSS = {
    preprocessorOptions: {
        scss: {
            silenceDeprecations: ['import', 'global-builtin', 'color-functions', 'if-function'],
        }
    },
    postcss: {
        plugins: [autoprefixer()]
    }
};

/** Shared module aliases */
const sharedResolve = {
    alias: {
        '@': resolve(__dirname, 'http_src'),
        'vue': isProd
            ? 'vue/dist/vue.esm-browser.prod.js'
            : 'vue/dist/vue.esm-browser.js'
    }
};

/** Vite plugin: compress PNG/JPEG/GIF assets using imagemin (production only) */
const imageminPlugin = isProd ? {
    name: 'vite-plugin-sharp',
    async generateBundle(_, bundle) {
        for (const [fileName, asset] of Object.entries(bundle)) {
            if (asset.type !== 'asset') continue;
            const src = Buffer.from(asset.source);

            try {
                let compressed;
                if (/\.(jpg|jpeg)$/i.test(fileName)) {
                    compressed = await sharp(src).jpeg({ progressive: true, quality: 80 }).toBuffer();
                } else if (/\.png$/i.test(fileName)) {
                    compressed = await sharp(src).png({ compressionLevel: 9, quality: 80 }).toBuffer();
                } else if (/\.gif$/i.test(fileName)) {
                    continue; // sharp doesn't process GIFs, skip
                } else {
                    continue;
                }

                if (compressed.length < src.length) {
                    asset.source = compressed;
                    console.log(`  sharp: ${fileName} ${src.length} → ${compressed.length} bytes`);
                }
            } catch (e) {
                console.warn(`  sharp: skipped ${fileName} — ${e.message}`);
            }
        }
    }
} : null;

/** Asset output path rules */
const assetFileNames = (assetInfo) => {
    const name = assetInfo.names?.[0] || '';
    if (/\.(png|gif|svg|jpg|jpeg|ico)$/i.test(name)) return 'images/[name][extname]';
    if (/\.(woff2?|ttf|eot|otf)$/i.test(name))       return 'assets/[name][extname]';
    return '[name][extname]';
};

const handleEvalFiles = {
    name: 'handle-eval-files',
    transform(code, id) {
        if (id.includes('store-js/plugins/lib/json2.js') ||
            id.includes('jquery.tablesorter.js')) {
            return { code, map: null };
        }
    }
};

/* Suppress eval warnings from third-party files as we cannot fix them */
const onwarnSuppressEval = (warning, defaultHandler) => {
    if (warning.code === 'EVAL' && warning.id &&
        (warning.id.includes('store-js/plugins/lib/json2.js') ||
         warning.id.includes('jquery.tablesorter.js'))) {
        return;
    }
    defaultHandler(warning);
};

/**
 * The inject plugin adds `import $ from 'jquery'` (and jQuery / moment)
 * to any module that uses those names as free variables without importing them.
 * This covers legacy vendor scripts (bootstrap-datatable, bootstrap-select,
 * jquery.tablesorter, etc.) that assume jQuery is available as a global.
 */
const injectGlobals = inject({
    $: 'jquery',
    jQuery: 'jquery',
    moment: 'moment-timezone',
    include: ['**/*.js', '**/*.ts', '**/*.vue', '**/*.mjs'],
    exclude: ['**/*.css', '**/*.scss', '**/*.sass'],
});

// Build 1: third-party.js
// Self-contained IIFE — bundles jQuery, Bootstrap, DataTables, Leaflet, etc.
// and exposes them as window globals (window.$, window.moment, window.L ...).
//
console.log('[1/5] Building third-party.js ...');
await build({
    plugins: [injectGlobals, handleEvalFiles, imageminPlugin].filter(Boolean),
    css: sharedCSS,
    // base: '' -> relative asset paths in CSS
    // so fonts resolve correctly when third-party.css is served from /dist/
    base: '',
    build: {
        outDir: 'httpdocs/dist',
        emptyOutDir: true,           // wipe dist only on the first build step
        cssCodeSplit: false,         // extract CSS to a file (not inline via __vite_style__)
        sourcemap: !isProd,
        minify: isProd ? 'esbuild' : false,
        chunkSizeWarningLimit: 5000,
        rollupOptions: {
            context: 'window',
            onwarn: onwarnSuppressEval,
            input: { 'third-party': resolve(__dirname, 'assets/third-party.js') },
            output: {
                format: 'iife',
                name: 'ntopThirdParty',
                entryFileNames: '[name].js',
                assetFileNames,
                strict: false,
            }
        }
    }
});

// Vite names the CSS 'style.css' -> rename to match ntopng format
renameSync(resolve(__dirname, 'httpdocs/dist/style.css'), resolve(__dirname, 'httpdocs/dist/third-party.css'));

// Build 2: ntopng.js
console.log('[2/5] Building ntopng.js ...');
await build({
    plugins: [vue(), injectGlobals, handleEvalFiles, imageminPlugin].filter(Boolean),
    css: sharedCSS,
    resolve: sharedResolve,
    base: '',
    build: {
        outDir: 'httpdocs/dist',
        emptyOutDir: false,
        cssCodeSplit: false,         // extract CSS to a file (not inline via __vite_style__)
        sourcemap: !isProd,
        minify: isProd ? 'esbuild' : false,
        chunkSizeWarningLimit: 5000,
        rollupOptions: {
            onwarn: onwarnSuppressEval,
            input: { ntopng: resolve(__dirname, 'http_src/ntopng.js') },
            external: ['jquery', 'moment', 'moment-timezone'],
            output: {
                format: 'iife',
                name: 'ntopVue',
                entryFileNames: '[name].js',
                assetFileNames,
                globals: {
                    'jquery': '$',
                    'moment': 'moment',
                    'moment-timezone': 'moment',
                }
            }
        }
    }
});

// Vite names the CSS 'style.css' -> rename to match ntopng format
renameSync(resolve(__dirname, 'httpdocs/dist/style.css'), resolve(__dirname, 'httpdocs/dist/ntopng.css'));


// Build 3: CSS theme bundles (dark-mode, white-mode, custom-theme) — sequential
console.log('[3/5] Building theme CSS files ...');
const cssEntries = [
    { entry: 'http_src/views/private/clients/dark-mode.js',    name: 'dark-mode'     },
    { entry: 'http_src/views/private/clients/white-mode.js',   name: 'white-mode'    },
    { entry: 'http_src/views/private/clients/custom_theme.js', name: 'custom-theme'  },
];

for (const { entry, name } of cssEntries) {
    await build({
        plugins: [imageminPlugin].filter(Boolean),
        css: sharedCSS,
        base: '',
        build: {
            outDir: 'httpdocs/dist',
            emptyOutDir: false,
            cssCodeSplit: false,     // extract CSS to a file (not inline via __vite_style__)
            minify: isProd ? 'esbuild' : false,
            rollupOptions: {
                input: { [name]: resolve(__dirname, entry) },
                output: {
                    format: 'iife',
                    // Replace hyphens so the IIFE wrapper variable is a valid identifier
                    name: name.replace(/-/g, '_'),
                    entryFileNames: '[name].js',
                    assetFileNames,
                }
            }
        }
    });
    // Vite names the CSS 'style.css' -> rename to match ntopng format
    renameSync(resolve(__dirname, 'httpdocs/dist/style.css'), resolve(__dirname, `httpdocs/dist/${name}.css`));
}

// Build 4: images
console.log('[4/5] Copying images ...');
await build({
    plugins: [imageminPlugin].filter(Boolean),
    build: {
        outDir: 'httpdocs/dist',
        emptyOutDir: false,
        assetsInlineLimit: 0,
        rollupOptions: {
            input: { images: resolve(__dirname, 'assets/images/images.js') },
            output: {
                format: 'iife',
                name: 'ntopImages',
                entryFileNames: '[name].js',
                assetFileNames,
            }
        }
    }
});

// Standalone IIFE for the login page particle animation.
console.log('[5/5] Building login.js ...');
await build({
    plugins: [imageminPlugin].filter(Boolean),
    build: {
        outDir: 'httpdocs/dist',
        emptyOutDir: false,
        minify: isProd ? 'esbuild' : false,
        reportCompressedSize: false,
        rollupOptions: {
            input: { login: resolve(__dirname, 'assets/scripts/login.js') },
            output: {
                format: 'iife',
                name: 'ntopLogin',
                entryFileNames: '[name].js',
                assetFileNames,
                strict: false,
            }
        }
    }
});

// gzip files for static serving
if (isProd) {
    console.log('\n[+] Compressing JS and CSS ...');
    const distDir = resolve(__dirname, 'httpdocs/dist');
    for (const file of readdirSync(distDir).filter(f => /\.(js|css)$/.test(f))) {
        const filePath = resolve(distDir, file);
        const content = readFileSync(filePath);
        const compressed = gzipSync(content, { level: 9 });
        if (compressed.length < content.length) {
            writeFileSync(filePath + '.gz', compressed);
            const ratio = ((1 - compressed.length / content.length) * 100).toFixed(1);
            console.log(`  ${file}: ${(content.length / 1024).toFixed(0)}KB → ${(compressed.length / 1024).toFixed(0)}KB (-${ratio}%)`);
        }
    }
}

console.log('\nBuild complete.');
