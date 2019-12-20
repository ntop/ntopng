--
-- (C) 2013-19 - ntop.org
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

  -- Conditionally show or hide the menu entry
  is_shown = function()
    return(true)
  end,
}
