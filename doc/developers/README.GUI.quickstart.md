## GUI quickstart guide

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
- `httpdocs/` is the folder for GUI data, dist folder is present inside it
- `template.render("pages/vue_page.template", { vue_page_name = "PageSNMPDevices", page_context = json_context })` some .lua pages render vue components. The name of the component is the value of `vue_page_name`, in this case the component is `PageSNMPDevices`. This is the name of the component importend in the script `http_src/vue/ntop_vue.js`. This is the import: `import { default as PageSNMPDevices } from "./page-snmp-devices.vue"` where PageSNMPDevices is the name of the vue component imported and displayed on the webpage and the component is found in the file page-snmp-devices.vue

- The navbar that is present at the left of each page is rendered with lua function: `page_utils.print_header_and_set_active_menu_entry(page_utils.VALUE)` where VALUE is the name of the entry that is found inside `page_utils.lua` (scripts/lua/modules/page_utils.lua). Please refer to Lua Navbar section later in this document for more info.


## Webpage structure

Pages are rendered lua side, rendering .vue components inside of the pages that need them.

- How to find .vue components that are used on a page?
    1. take the path of the current webpage and the .lua file that renders it is found
    2. prepend `scipts/` to the page path and the file is opened
    3. `template.render("VUE-COMPONENT-PATH", { vue_page_name = "PAGE-NAME", page_context = json_context })` this function renders VUE-COMPONENT-PATH vue component
- Each page has a `page=*` parameter where * is the name of the page. * is used to route each page and have conditional rendering lua side

## Lua Navbar

- `page_utils.menu_sections` is a Lua table used within our application to store the bindings between different entries in the navbar. Sections are the names under the icons that are found when first opening a page in ntopng

The structure of `page_utils.menu_sections` follows a key-value pair format, where each entry represents a specific item in the navbar entry. Here's the breakdown:

- **Key**: Represents the unique identifier for the navbar entry.
- **Values**: An object containing various attributes of the navbar entry, such as:
  - `i18n_title`: The title of the entry. Mappings are found in the file `scripts/locales/en.lua`
  - `section`: The section to which the entry belongs. Section refers to the father component of the navbar, values are found in `page_utils.menu_sections`
  - `icon` is the icon to display in the navbar
  - `help_link` (optional): Provides a URL link for additional help or information related to the entry. This icon is displayed in the top right side of each page header.


- `page_utils.menu_entries` is a Lua table used within our application to store the bindings between different entries in navbar sections. This table organizes these entries into sections, making it easier to manage and navigate through the various sections of the application. `Entries` are the available options that pop up when hovering on a section. The same description as page_utils.menu_section is available with only difference that the **Values** table contains a new option: `section` which is used to link a menu entry to the parent section of the navbar.

