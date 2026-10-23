--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require("lua_utils")
require("http_lint")

local rest_utils = require("rest_utils")
local site_utils = require("site_utils")

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local network_id = _POST["network"]
local network_alias = _POST["custom_name"]
local network_site = _POST["site_id"]

if not isEmptyString(network_site) then
	local site_utils = require("site_utils")
	site_utils.mapNetworkToSite(network_id, network_site)
	ntop.refreshNetworkSiteId(tonumber(network_id))
end

if not isEmptyString(network_alias) then
	local network_cidr = ntop.getNetworkNameById(tonumber(network_id))
	setLocalNetworkAlias(network_cidr, network_alias)
end

rest_utils.answer(rest_utils.consts.success.ok)
