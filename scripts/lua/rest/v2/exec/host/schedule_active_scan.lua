--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path

require "http_lint"
local rest_utils = require "rest_utils"
local ascan_utils = require "ascan_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if not ascan_utils.is_nmap_installed() then
   rest_utils.answer(rest_utils.consts.err.not_enabled, {error = i18n("hosts_stats.page_scan_hosts.nmap_not_installed")})
   return
end

-- A write (it runs nmap): _POST, filled only with a valid CSRF
local host = _POST["host"]
local scan_type = _POST["scan_type"]
local ports = _POST["scan_ports"]
local single_host = toboolean(_POST["scan_single_host"]) or false
local scan_id = _POST["scan_id"]
local cidr = _POST["vs_cidr"]

if single_host then 
   -- The host goes to the nmap command line: a plain IP address (as add/host/to_scan.lua)
   if isEmptyString(host) or not (isIPv4(host) or isIPv6(host)) or not ascan_utils.is_valid_scan_type(scan_type) then
      rest_utils.answer(rest_utils.consts.err.invalid_args)
      return
   end

   local is_single_scan = single_host
   local is_all = not single_host
   local is_periodic = not single_host

   local res = ascan_utils.schedule_ondemand_single_host_scan(scan_type, host, ports, scan_id, is_periodic, is_all, is_single_scan, cidr)

   if res then
      rest_utils.answer(rest_utils.consts.success.ok)
   else 
      rest_utils.answer(rest_utils.consts.err.internal_error)

   end
else 
   local res = ascan_utils.schedule_ondemand_all_hosts_scan()

   if res then
      rest_utils.answer(rest_utils.consts.success.ok)
   else 
      rest_utils.answer(rest_utils.consts.err.internal_error)

   end
end

