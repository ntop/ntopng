--
-- (C) 2019-20 - ntop.org
--

-- This file contains the plugin metadata information.

-- NOTE: Plugins are loaded at startup, any change to this plugin
-- can be applied by restarting ntopng or by manually reloading the
-- plugins from http://127.0.0.1:3000/lua/plugins_overview.lua .

return {
  title = "Webhook Alert Endpoint",
  description = "Provides alerts notifications via webhooks",
  author = "ntop",
  version = 1,
  dependencies = {},
}
