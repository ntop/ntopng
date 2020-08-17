.. _Custom Pages:

Custom Pages
============

Plugins can provide custom pages to be added to the ntopng menu bar. They are
fully customizable pages, which can define they own style and functionalities.

The custom pages are defined into the `./web_gui` subdirectory of the plugin. Let's analyze the
`example plugin`_  as an example.

Custom Pages Definition
-----------------------

The file `menu.lua` is used to define the custom menu entry:

.. code:: lua

  return {
    label = "example.custom_menu_entry",
    script = "example_page.lua",
    sort_order = -1,
    menu_entry = {key = "example_plugin", i18n_title = "Example Page", section = "system_stats"},
    is_shown = function()
      return(true)
    end,
  }

The Lua script returns a table with the following structure:

- :code:`label`: A localized message for the label of the menu entry. The localization strings
  can be supplied by the plugin as explained in the `Localization section`_.
- :code:`script`: the unique file name of the script to be visited when the user selects the menu entry.
  The script must be located into the same directory of `menu.lua`.
- :code:`sort_order`: The sort order in the menu. Entries with higher sort_order are shown
  before entries with lower sort order.
- :code:`menu_entry`: Contains information about the menu entry. In particular, the following
  elements are required: `key` defines a unique key for this menu entry, `i18n_title` contains
  a localized title for the page, `section` indicates to which menu section the entry should
  be attached (for now only "system_stats" is supported). Check out `menu_entries` in `page_utils.lua`_ for more details.
- :code:`is_shown`: can be used to programmatically hide a menu entry. If defined, it must be a
  Lua function which returns true when the entry should be shown, false otherwise.

The actual page is implemented in the Lua script referenced in the `script` parameter above.

Page Skeleton
-------------

As explained above, any Lua script can be linked to the ntopng menu. In order to provide
a consistent look, custom pages can use the following template:

.. code:: lua

  -- Set up the modules path
  local dirs = ntop.getDirs()
  package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

  -- Load some essential modules
  require "lua_utils"
  local page_utils = require("page_utils")

  -- Setup up the page header. The "example_plugin" key below is taken
  -- from the menu_entry "key" as defined in menu.lua.
  sendHTTPContentTypeHeader('text/html')
  page_utils.set_active_menu_entry(page_utils.menu_entries.example_plugin)
  dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

  local subpage = _GET["page"] or "overview"
  local title = i18n("example.custom_page_title")
  local base_url = plugins_utils.getUrl("example_page.lua") .. "?ifid=" .. getInterfaceId(ifname)

  -- Populate the navbar with subpages
  page_utils.print_navbar(title, base_url, {
     {
	active = (subpage == "overview"),
	page_name = "overview",
	label = "<i class=\"fas fa-lg fa-home\"></i>",
     },
  })

  -- Subpages logic here
  if(subpage == "overview") then
    -- "overview" subpage logic here
  end

  dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

Once the plugin is loaded, ntopng will make the above page available through its
web server. The URL for a given custom page can be obtained by using the `plugins_utils.getUrl(script)`
Lua function.

.. _`example plugin`: https://github.com/ntop/ntopng/tree/dev/scripts/plugins/example/web_gui
.. _`Localization section`: https://www.ntop.org/guides/ntopng/plugins/localization.html
.. _`page_utils.lua`: https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/page_utils.lua
