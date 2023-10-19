--
-- (C) 2013-23 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- Imports
require "lua_utils"
local graph_utils = require "graph_utils"
local rest_utils = require "rest_utils"
local inactive_hosts_utils = require "inactive_hosts_utils"

-- Local variables

local ifid        = _GET["ifid"] or interface.getId()
interface.select(tostring(ifid))

local active_hosts = interface.getStats().stats.local_hosts
local inactive_hosts = inactive_hosts_utils.getInactiveHostsNumber(ifid)--, inactive_hosts_utils.getFilters())

local rsp = {
  series = {},
  labels = {},
  colors = {},
  yaxis = {
    labels = {}
  },
  tooltip = {
    y = {}
  }
}

-- ##################################

rsp["series"] = {
  tonumber(active_hosts),
  tonumber(inactive_hosts)
}
rsp["labels"] = {
  i18n('graphs.active_hosts'),
  i18n('graphs.inactive_hosts')
}
rsp["colors"] = {
  graph_utils.get_html_color(1),
  graph_utils.get_html_color(2),
}

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
