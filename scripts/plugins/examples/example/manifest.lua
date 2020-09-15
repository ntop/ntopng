--
-- (C) 2019-20 - ntop.org
--

-- This file contains the plugin metadata information.

-- NOTE: Plugins are loaded at startup, any change to this plugin
-- can be applied by restarting ntopng or by manually reloading the
-- plugins from http://127.0.0.1:3000/lua/plugins_overview.lua .

return {
  -- The (unique) name of the plugin
  title = "Example Plugin",

  -- A description of the functionalities offered by the plugin
  description = "An example to show how to write ntopng plugins",

  -- The author of the plugin. For emails use the format: 'Name Surname <me@domain.com>'
  author = "ntop",

  -- A list of plugin keys which this plugin depends on. A plugin key
  -- corresponds to the directory name of the plugin (e.g. the key of
  -- this plugin is "example")
  dependencies = {},

  -- A disabled plugin will not be loaded.
  -- Comment this and reload the plugins to activate this test plugin.
  disabled = true,
}
