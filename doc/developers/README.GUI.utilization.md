## GUI utilization guide

To create the dist of ntopng (compile vue code):
- npm run build (to build css and js for the first time building)
- npm run build:js (to only build the js part)

- `/scripts/locales/en.lua` is a config file with key value pairs that are used in the GUI. Each key is used inside the GUI to display the relative value. Binding is done via utility function i18n:
    1. `i18n(ENTRY)` which displays the value of ENTRY
    2. `i18n(ENTRY.ENTRY1)` which displays the value of ENTRY1 which is inside the dict ENTRY. This in case of nested keys

- Navbar rendering in a page
    Pages that have a navbar can be configured to display additional icons or textual data. Simply find the line that contains `page_utils.print_navbar(.., .., ..)` the third param is an object that contains entries in the navbar. To add a new entry copy an existing entry and change values. 
    1. `active` is used to highlight which page is currently selected
    2. `page_name` refers to the name of the page
    3. `url` (if present) represent the url to which you will be redirected if the icon or name is clicked. A utility function is present "ntop.getHttpPrefix()" which gets the url prefix for the ntopng instance, concatenate after the base url the params that are needed to be redirected to the target page
    4. `label` is an html template icon. To display a tooltip on hover insert this in the html tag `data-bs-toggle=\"tooltip\" data-bs-placement=\"top\" title=\"" .. i18n(<ENTRY>) .. "\"`. <ENTRY> is a string to display content inside the tooltip. To retrieve ENTRY value please check `scripts/locales/en.lua` and search a relevant name to insert in the tooltip. If a relevant name is not present add an entry in the appropriate section inside en.lua
