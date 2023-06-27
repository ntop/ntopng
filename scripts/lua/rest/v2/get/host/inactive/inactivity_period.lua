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
local filters = inactive_hosts_utils.getFilters()
local inactive_hosts_distribution = inactive_hosts_utils.getInactiveHostsEpochDistribution(ifid)--, filters)

local series = {}
local labels = {}
local colors = {}
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

if (inactive_hosts_distribution.last_hour 
    + inactive_hosts_distribution.last_day
    + inactive_hosts_distribution.last_week
    + inactive_hosts_distribution.older > 0) then
  rsp["series"] = {
    inactive_hosts_distribution.last_hour,
    inactive_hosts_distribution.last_day,
    inactive_hosts_distribution.last_week,
    inactive_hosts_distribution.older
  }
  rsp["labels"] = {
    i18n("show_alerts.last_hour"),
    i18n("show_alerts.last_day"),
    i18n("show_alerts.last_week"),
    i18n("show_alerts.older_then_a_week")
  }
  rsp["colors"] = {
    graph_utils.get_html_color(1),
    graph_utils.get_html_color(2),
    graph_utils.get_html_color(3),
    graph_utils.get_html_color(4)
  }
end

-- ##################################

rest_utils.answer(rest_utils.consts.success.ok, rsp)
