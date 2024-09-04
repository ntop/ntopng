
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local json = require "dkjson"

local ifid = tonumber(_GET["ifid"])


local res = {}

if isEmptyString(ifid) then
    rest_utils.answer(rest_utils.consts.err.invalid_interface)
    return
end

-- Get data from redis: expected format, array of objects with keys: 
res = {
   {key= "dns_list", value_description=ntop.getCache("ntopng.prefs.nw_config_dns_list") or "" },
   {key= "ntp_list", value_description=ntop.getCache("ntopng.prefs.nw_config_ntp_list") or "" },
   {key= "dhcp_list", value_description=ntop.getCache("ntopng.prefs.nw_config_dhcp_list") or "" },
   {key= "smtp_list", value_description=ntop.getCache("ntopng.prefs.nw_config_smtp_list") or "" },
   {key= "gateway_list", value_description=ntop.getCache("ntopng.prefs.nw_config_gateway_list") or "" },
}

rest_utils.answer(rest_utils.consts.success.ok, res)
