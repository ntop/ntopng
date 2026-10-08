
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
local ssh_list = _POST["ssh_list"]
local powershell_list = _POST["powershell_list"]
local ftp_list = _POST["ftp_list"]
local rdp_list = _POST["rdp_list"]
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

if rdp_list then
   local parsed_rdp_list = rdp_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_rdp_list", parsed_rdp_list)
end

if ftp_list then
   local parsed_ftp_list = ftp_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_ftp_list", parsed_ftp_list)
end

if ssh_list then
   local parsed_ssh_list = ssh_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_ssh_list", parsed_ssh_list)
end

if powershell_list then
   local parsed_powershell_list = powershell_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_powershell_list", parsed_powershell_list)
end

if gateway_list then
   local parsed_gateway_list = gateway_list:gsub("%s+", "") -- Remove the empty spaces
   ntop.setCache("ntopng.prefs.nw_config_gateway_list", parsed_gateway_list)
end

ntop.reloadServersConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, res)
