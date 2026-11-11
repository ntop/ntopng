Introduction
============

ntopng uses npm (Node Package Manager) to lint, build and minimize CSS, JS and image files. To do it npm uses Webpack with Babel for the JS part and other plugins for the CSS and images minimization and linting.<br />
All the processed files are added in `httpdocs/dist` directory; the files in that directory SHOULD NOT be modified because they are removed and re-added each time webpack is launched.

Install
-------
npm is a module of NodeJS, so other then npm, NodeJS is required to operate with npm.

`sudo apt-get install nodejs npm jq` (in Ubuntu/Debian)

After installing npm, all the npm modules used by ntopng front-end need to be downloaded.

`npm install` <br />

Now all the required packages are ready.

Build
-----
npm has various scripts configured. The main scripts are `build` and `build:dev`.<br />
`npm run build:dev` should be used while developing (it uses Webpack Development mode). <br />
`make dist-ntopng` should be used to push changes in GitHub.<br />

Developing
----------
Whenever a JS or SCSS file is modified the npm run build should be executed to see the changes in the Web GUI.
When adding a new JS or SCSS file, the import of that file should be added in one of the following, depending on the role of the file:
`http_src/utilities/utilities`<br />
`http_src/validators/validators`<br />
`http_src/components/components`<br />
`http_src/services/services`<br />
`http_src/views/views`<br />
`http_src/routes/routess`<br />

(Check `http_src/components/components.js` as an example. The import should be done in the .scss if a new scss file is added or into the .js file if a new .js file is added).

A new external library imported by a Vue component is bundled in `ntopng.js` by that import. A library the legacy Lua pages use through a window global goes in `pro/assets/third-party.js`, its CSS in `pro/assets/third-party.scss`.
