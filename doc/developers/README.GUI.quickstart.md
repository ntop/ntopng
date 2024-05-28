## GUI utilization guide

This guide is a quickstart to get up and running for GUI development

1. Make sure to have node.js installed
2. Run `npm install` to install all the dependencies
3. Before making changes to any page make sure to run `npm run watch` so that changes are displayed after every file save
4. After having made changes please build with the appropriate command.
    - `npm run build:ntopng.js` to compile js only. If CSS changes have not been done
    - `npm run build:ntopng.js` to compile css only. If JS changes have not been done
    - `npm run build` to compile all the changes

## Project structure

The folder `http_src/` contains all the webpages scripts. 

- `http_src/vue` contains single vue components that are imported in desired pages
- `http_src/utilities` contains all utility functions 
- `http_src/ntopng.js` contains all global imports that will be visible inside single components
- `pages/` is found in `httpdocs/templates/pages/`
- `httpdocs` is the folder for GUI data, dist folder is present inside it

## Webpage structure

Pages are rendered lua side, rendering .vue components inside of the pages that need them.

- How to find .vue components that are used on a page?
    1. take the path of the current webpage and the .lua file that renders it is found
    2. prepend `scipts/` to the page path and the file is opened
    3. `template.render("VUE-COMPONENT-PATH", { vue_page_name = "PAGE-NAME", page_context = json_context })` this function renders VUE-COMPONENT-PATH vue component
- Each page has a `page=*` parameter where * is the name of the page. * is used to route each page and have conditional rendering lua side