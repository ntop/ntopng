
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}
local dns_list = _POST["dns_list"]
local ntp_list = _POST["ntp_list"]
local smtp_list = _POST["smtp_list"]
local dhcp_list = _POST["dhcp_list"]
local gateway_list = _POST["gateway_list"]

if dns_list then
   local parsed_dns_list = dns_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_dns_list", parsed_dns_list)
end

if ntp_list then
   local parsed_ntp_list = ntp_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_ntp_list", parsed_ntp_list)
end

if smtp_list then
   local parsed_smtp_list = smtp_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_smtp_list", parsed_smtp_list)
end

if dhcp_list then
   local parsed_dhcp_list = dhcp_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_dhcp_list", parsed_dhcp_list)
end

if gateway_list then
   local parsed_gateway_list = gateway_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_gateway_list", parsed_gateway_list)
end

ntop.reloadServersConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, res)
