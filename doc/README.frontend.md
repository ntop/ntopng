# Frontend Development (Javascript/Vue/CSS)

The client side of the ntopng frontend is based on html/javascript/css/vue. Part of this (old style) is generated by Lua script. Instead new pages are written in modern html/javascript/css/vue and must be compiled.
Ntopng is currently using npm to compile the frontend code (JS/CSS) under httpdocs/dist.
Foreach file modified in http_src you must recompile httpdocs/dist.

## Installation
To compile the new modern frontend part written in http_src you must have nodejs >= 18.15.0.
To install nodejs on Ubuntu run these command:
```
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - &&\
sudo apt-get install -y nodejs
```
On others Linux distributions to install nodeJs you can:
- download nodejs from https://nodejs.org/dist/v18.15.0/node-v18.15.0-linux-x64.tar.xz
- decompress nodejs tar with:
```
tar -xvf node-v18.15.0-linux-x64.tar.xz
```
- export path of node-v18.15.0-linux-x64/bin:
```
export PATH=$PATH:$(pwd)/node-v18.15.0-linux-x64/bin
```

Install dependencies required for the frontend compilation:

```
npm install
```

## Quick Start


In order to automatically recompile the code (debug mode) whenever a change to the
frontend source files under http_src/ has been detected:

```
npm run watch 
```

In order to compile frontend source files under http_src/ for production (ntopngjs bundle only):

```
npm run build:ntopngjs
```

In order to compile for production (only for third party code or CSS):

```
npm run build
```

Do not forget to commit your httpdocs/dist files (or send a pull request) !
