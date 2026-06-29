--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"
local rest_utils = require("rest_utils")

local ok, err = pcall(function()


local info  = ntop.getInfo()  or {}
local prefs = ntop.getPrefs() or {}

local pro = info.pro or {}

local license_day_left = info["pro.license_days_left"] or 0
local license_type     = info["pro.license_type"] or ""

local license_end_date = ""
if info["pro.license_ends_at"] then
   license_end_date = os.date("%Y-%m-%d %H:%M:%S", tonumber(info["pro.license_ends_at"]))
end

local res = {
   product        = info.product or "",
   version        = info.version or {},
   os             = info.OS or "",
   platform       = info.platform or "",
   command_line   = info.command_line or "",
   zoneinfo       = info.zoneinfo or "",
   max_num_hosts  = prefs.max_num_hosts or 0,
   max_num_flows  = prefs.max_num_flows or 0,

   license = {
      days_left = license_day_left,
      end_date  = license_end_date,
      type      = license_type
   }
}


rest_utils.answer(rest_utils.consts.success.ok, res)

end)

if not ok then
rest_utils.answer(rest_utils.consts.success.ok, {})
end