--
-- (C) 2013-20 - ntop.org
--

-- Adds a custom page to the ntopng system menu

-- Changes to this script must be applied by reloading the plugins from
-- http://127.0.0.1:3000/lua/plugins_overview.lua

return {
  -- The menu entry label
  label = "example.custom_menu_entry",

  -- The custom script to execute, located into this directory.
  script = "example_page.lua",

  -- The sort order in the menu. Entries with higher sort_order are shown
  -- before entries with lower sort order.
  sort_order = -1,

  -- Information about the menu entry, see page_utils.menu_entries
  menu_entry = {key = "example_plugin", i18n_title = "Example Page", section = "system_stats"},

  -- Conditionally show or hide the menu entry
  is_shown = function()
    return(true)
  end,
}
