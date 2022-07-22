# Frontend Development (Javascript/Vue/CSS)

ntopng is currently using npm to compile the frontend code (JS/CSS) under httpdocs/dist

## Quick Start

Install dependencies required for the frontend compilation:

```
npm install
```

In order to automatically recompile the code (debug mode) whenever a change to the
frontend source files has been detected:

```
npm run watch
```

In order to compile for production (ntopngjs bundle only):

```
npm run build:ntopngjs
```

In order to compile for production (also third party code):

```
npm run build
```

