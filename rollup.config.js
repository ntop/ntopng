import replace from 'rollup-plugin-replace';
import terser from '@rollup/plugin-terser';
import { babel } from '@rollup/plugin-babel';
import minimist from 'minimist';
import vue from 'rollup-plugin-vue';
import alias from 'rollup-plugin-alias';
import PostCSS from 'rollup-plugin-postcss';
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
// import css from 'rollup-plugin-css-only';
//import nodeResolve from '@rollup/plugin-node-resolve';
import json from '@rollup/plugin-json';


const argv = minimist(process.argv.slice(2));

let vue_path = 'node_modules/vue/dist/vue.esm-browser.js';
if (argv && argv.prod) {
    vue_path = 'node_modules/vue/dist/vue.esm-browser.prod.js'
}

const buildFormat = {
    input: './http_src/ntopng.js',
    plugins: [
        replace({
            'process.env.NODE_ENV': JSON.stringify('production')
        }),
        vue(),
        PostCSS({
            modules: {
                generateScopedName: '[local]___[hash:base64:5]',
            },
            include: /&module=.*\.css$/,
        }),
        PostCSS({ include: /(?<!&module=.*)\.css$/ }),
        alias({
            entries: [
                { find: "vue", replacement: vue_path }
            ]
        }),
        resolve(),
        commonjs(),
        json(),
    ],
    // external: ["vue", "Vue"],
    output: {
        file: './httpdocs/dist/ntopng.js',
        format: 'iife',
        name: 'ntopng',
        sourcemap: argv && argv.prod ? "inline" : false,
    },
    watch: {
        chokidar: {},
        exclude: ['node_modules/**']
    }
};

if (argv && argv.prod) {
    let babelPlugin = babel({
        extensions: ['.js', '.jsx', '.ts', '.tsx', '.vue'],
        babelHelpers: 'bundled'
    });
    let terserPlugin = terser({
        output: {
            ecma: 5,
        },
    });

    buildFormat.plugins.push(babelPlugin);
    buildFormat.plugins.push(terserPlugin);
}
export default buildFormat;
