# ntopng 

[![Build Status](https://img.shields.io/github/actions/workflow/status/ntop/ntopng/build.yml?branch=dev&logo=github)](https://github.com/ntop/ntopng/actions?query=workflow%3ABuild)
[![Fuzzing Status](https://oss-fuzz-build-logs.storage.googleapis.com/badges/ntopng.svg)](https://bugs.chromium.org/p/oss-fuzz/issues/list?sort=-opened&can=1&q=proj:ntopng)
[![Gurubase](https://img.shields.io/badge/Gurubase-Ask%20ntopng%20Guru-006BFF)](https://gurubase.io/g/ntopng)

### Introduction

ntopng® is a web-based network traffic monitoring application released under GPLv3. It is the new incarnation of the original ntop written in 1998, and now revamped in terms of performance, usability, and features.

While you can read more about ntopng on the ntop web site (http://www.ntop.org), we suggest you to start reading the [doc/README.md](https://github.com/ntop/ntopng/blob/dev/doc/README.md) file for learning how to compile and use ntopng.

If instead of source code you prefer to use a pre-built package, please go to http://packages.ntop.org

We build binary packages for the following platforms:
* Debian/Ubuntu LTS x64
* CentOS/RedHat/RockyLinux/AlmaLinux x64
* Windows x64
* RaspberryPI/Debian ARM
* FreeBSD/OPNsense/pfSense

Enjoy.

### Documentation

If you want to learn more about ntopng please visit the [User's Guide](https://www.ntop.org/guides/ntopng/) and the [API Documentation](https://www.ntop.org/guides/ntopng/api/index.html) or watch our [latest webinar](https://www.youtube.com/watch?v=dtLrax-_ZNs).


### Building the User's Guide

The User's Guide is a [VitePress](https://vitepress.dev) project in `doc/nedge/src/` (Markdown pages, same
URLs as the old Sphinx guide: `/guides/nedge/<page>.html`). Requires Node 18+ and `make`.

```
cd doc/nedge/src
make dist      # build the static site into doc/nedge/src/dist (runs npm install if needed)
make serve     # build, then serve it at http://localhost:4173/guides/nedge/   (PORT=8080 make serve)
```

To publish, copy the result where the guide is served from, e.g.
`rsync -a --delete dist/ user@server:/var/www/ntop.org/guides/nedge/`.
For live reload while editing a page use `npm run dev` (http://localhost:5173/guides/nedge/).

### Details
For more information about ntopng, please visit [http://ntop.org](https://www.ntop.org/products/traffic-analysis/ntop/)

ntopng is a registered trademark in the US and EU.

[ntopng_logo]: https://camo.githubusercontent.com/0f789abcef232035c05e0d2e82afa3cc3be46485/687474703a2f2f7777772e6e746f702e6f72672f77702d636f6e74656e742f75706c6f6164732f323031312f30382f6e746f706e672d69636f6e2d313530783135302e706e67

[ntop_logo]: https://camo.githubusercontent.com/58e2a1ecfff62d8ecc9d74633bd1013f26e06cba/687474703a2f2f7777772e6e746f702e6f72672f77702d636f6e74656e742f75706c6f6164732f323031352f30352f6e746f702e706e67
