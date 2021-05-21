# Custom Bootstrap Theme

This folder contains a `scss` file used to create a custom Bootstrap theme used in ntopng when using the dark mode. 

## Requirements

In order to build the file is requested to have:

1. `npm` (any version)

2. A _Sass_ compiler, such as `sass` (see the installation page: https://sass-lang.com/install)

3. `cleancss` to minify and optimize the compiled css (https://www.npmjs.com/package/clean-css)

## Building

Once installed the requirements you have to types these commands in your shell:

```bash

# go inside the boostrap folder contained in ntopng/third-party/library/
cd /path/to/ntopng/third-party/bootstrap/

# download bootstrap from npm (https://www.npmjs.com/package/bootstrap)
npm install bootstrap

# build the scss file (in this example we are using Bootstrap 5.0.1)
BS_VERSION=5.0.1; sass main.scss bootstrap-$BS_VERSION-ntopng.css

# minidy the obatained css
BS_VERSION=5.0.1; cleancss -O3 bootstrap-$BS_VERSION-ntopng.css -o bootstrap-$BS_VERSION-ntopng.min.css

```

When the final CSS is ready we have to move the files under `bootstrap-custom/`. And eventually update page_utils.lua that contains the `<link>` tag used to import the new CSS file.
