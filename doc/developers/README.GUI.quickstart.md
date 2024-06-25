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

## General info

- System interface has id = -1

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

## Lua files

- `consts.lua` contains a list of available filters that are returned to the GUI (VueJS). Only these filters can be used as they are cross checked before doing table column filtering
- `menu.lua` contains a list of entries that are used inside the menu navbar
- `tag_utils.lua`  contains a list of available filters that can be used in frontend
- `flow_alert_store:_get_additional_available_filters()` contains available filters to filter columns inside a table. Entry name is used inside the JSON to configure the desired table in the key `data_field`. 
- `self:add_filter_condition_list('srv_ip', srv_ip)` -> is used to add a filter on a specific field, so that this filter is available to use frontend and backend side
- `scripts/lua/modules/http_lint.lua` is used to verify http requests parameters. When a parameter is passed, check that it is linted in this file. To add a new parameter to the checks, add an entry in the lua table as in the following example: `known_parameters` = { ["newParameterName"] = validationFunction }. Choose an appropriate validation function from the ones present in `http_lint.lua`
- To pass data to a vue page from lua rendering refer to this example:
  ```javascript
    local context = {
      ifid = interface.getId()
    }

    local json_context = json.encode(context)

    template_utils.render("pages/vue_page.template", {
      vue_page_name = "VUE-PAGE-MAPPING-INSIDE-ntopng_vue.js",
      page_context = json_context
    })
  ```
  context is the object that will be passed to the vuejs page when the render function is called. In this example the interface id is passed (ifid = interface.getId()) to access the value of context from a vue component refer to [Vue](#Vue) `context` entry in the paragraph below.
- The Preference page is made in lua, connected to the lua backend and saves settings in a redis cache that is accessed via the C++ ntopng engine. `scripts/lua/admin/prefs.lua` contains the preference page of ntopng `http://NTOPNG-INSTANCE-IP:PORT/lua/admin/prefs.lua`. To get and set preferencese a getter and setter are defined in lua, these getters and setters communicate with the C++ backend.
  ```javascript
  require "prefs_utils"
  ntop.getPref("ntopng.prefs.PREF-VALUE")
  ```
  
  `PREF-VALUE` can be found or added inside: `ntopng/include/ntop_defines.h`

  ```cpp
  #define PREF-VALUE 512 // int value
  #define CONST_DEFAULT_PREF-VALUE 0 // default value for this pref
  ```

  Inside `ntopng/include/Prefs.h` insert pref values and their relative getters and setters.
- `Lua <-> C++ connection` inside the files `LuaEngineCONNECTOR.cpp` is the mapping from lua to C++. For example `LuaEngineInterface.cpp` contains all the utility functions relative to the interface of the host running ntopng. Available functions for the interface in lua can be found in this file. To see available functions, refer to the variable present at the end of the file.
In the example below is exported the function `getId()` which is mapped to the C++ function `ntop_get_interface_id`:
  
  ```cpp
  {"getId", ntop_get_interface_id}
  ```

  can be accessed from lua with: 
  ```javascript
  local ifid = interface.getId()
  ```

## Vue 

- `map_table_def_columns = async (columns)` is a function used to manipulate table columns and apply some kind of filters. For example filterize can be applied
- `filterize` function adds filtering function to table columns if a value is clicked. Double check in front end and back end is executed to check if selected filter is available. 
- `formatterUtils.getFormatter(DATA-TYPE)(VALUE)` is a utility function that formats values to a specific unit of measure. Formatter utils can be found in `utilities/formatter-utils.js`. To format a value chose DATA-TYPE:String (possible values can be found inside types variable inside formatter utils) and pass a VALUE to format
- `ntop_utils.http_request(URL)` is used to make authenticated requests to the backend. Request parameters must be validated in the file `scripts/lua/modules/http_lint.lua`, se the Lua paragraph above for more details
- To utilize the function i18n in vue, initialize it like this inside the `<script setup> section of vue`: `const _i18n = (t) => i18n(t);`. 
  - _i18n(args) must be used inside the `<template>` section of a vue component or page. This is because i18n() cannot be used in the template as it is not defined for this usage
  - i18n(args) can be used inside the `<script setup>` section of a vue component or page as it is defined globally
- `context` to access the values passed as context from the lua rendering page, use this: 
  ```javascript
  const props = defineProps({
    context: Object,
  });

  const ifid = props.context.ifid;
  ```
  in this way from vue it is possible to access the ifid passed. To access other parameters do `const newParameter = props.context.newParameter`
- `ntopng_utility` is a class used please refer to the specific documentation file for the usage of this class: [Read more details](README.GUI.ntopng_utility_js.md)