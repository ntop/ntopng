import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { resolve } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { renameSync } from 'fs';
import inject from '@rollup/plugin-inject';
import autoprefixer from 'autoprefixer';

// For __dirname equivalent in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// This config is used exclusively for watch mode  and for build:ntopngjs
// Full JS + CSS + images check build.mjs.
export default defineConfig(({ mode }) => {
    const isProduction = mode === 'production';

    return {

        base: '',
        build: {
            outDir: 'httpdocs/dist',
            emptyOutDir: false,
            cssCodeSplit: false,     // extract CSS to ntopng.css
            sourcemap: !isProduction,
            minify: isProduction ? 'terser' : false,
            terserOptions: isProduction ? {
                compress: {
                    drop_console: true,
                },
                output: {
                    ecma: 5,
                },
            } : undefined,
            chunkSizeWarningLimit: 5000,
            rollupOptions: {
                plugins: [
                    inject({
                        $: 'jquery',
                        jQuery: 'jquery',
                        moment: 'moment-timezone'
                    })
                ],
                input: { ntopng: resolve(__dirname, 'http_src/ntopng.js') },
                // jQuery and moment are provided by third-party.js as window.$ / window.moment
                // Marking them external keeps ntopng.js lean and avoids duplicating those libraries
                external: ['jquery', 'moment', 'moment-timezone'],
                output: {
                    format: 'iife',
                    name: 'ntopVue',
                    entryFileNames: '[name].js',
                    assetFileNames: (assetInfo) => {
                        const name = assetInfo.name || '';
                        if (/\.(png|gif|svg|jpg|jpeg|ico)$/i.test(name)) {
                            return 'images/[name][extname]';
                        }
                        if (/\.(woff2?|ttf|eot|otf)$/i.test(name)) {
                            return 'assets/[name][extname]';
                        }
                        return '[name][extname]';
                    },
                    globals: {
                        'jquery': '$',
                        'moment': 'moment',
                        'moment-timezone': 'moment',
                    }
                }
            }
        },

        plugins: [
            vue(),
            {
                name: 'handle-eval-files',
                transform(code, id) {
                    if (id.includes('store-js/plugins/lib/json2.js') ||
                        id.includes('jquery.tablesorter.js')) {
                        return { code, map: null };
                    }
                }
            },
            // Vite names the CSS style.css -> rename it to ntopng.css after every build
            {
                name: 'rename-css-to-ntopng',
                closeBundle() {
                    renameSync(
                        resolve(__dirname, 'httpdocs/dist/style.css'),
                        resolve(__dirname, 'httpdocs/dist/ntopng.css')
                    );
                }
            }
        ],

        resolve: {
            alias: {
                '@': resolve(__dirname, 'http_src'),
                'vue': isProduction
                    ? 'vue/dist/vue.esm-browser.prod.js'
                    : 'vue/dist/vue.esm-browser.js'
            }
        },

        css: {
            preprocessorOptions: {
                scss: {
                    // Bootstrap 5.3.x uses legacy @import. Silence those warnings
                    silenceDeprecations: ['import', 'global-builtin', 'color-functions', 'mixed-decls'],
                }
            },
            postcss: {
                plugins: [
                    autoprefixer()
                ]
            }
        },
    };
});
