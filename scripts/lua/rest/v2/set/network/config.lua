
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local rest_utils = require "rest_utils"

local res = {}
local dns_list = _POST["dns_list"]
local ntp_list = _POST["ntp_list"]
local smtp_list = _POST["smtp_list"]
local dhcp_list = _POST["dhcp_list"]
local gateway_list = _POST["gateway_list"]

if dns_list then
   ntop.setCache("ntopng.prefs.nw_config_dns_list", dns_list)
end

if ntp_list then
   ntop.setCache("ntopng.prefs.nw_config_ntp_list", ntp_list)
end

if smtp_list then
   ntop.setCache("ntopng.prefs.nw_config_smtp_list", smtp_list)
end

if dhcp_list then
   ntop.setCache("ntopng.prefs.nw_config_dhcp_list", dhcp_list)
end

if gateway_list then
   ntop.setCache("ntopng.prefs.nw_config_gateway_list", gateway_list)
end

ntop.reloadServersConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, res)
