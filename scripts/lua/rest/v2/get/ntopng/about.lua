--
-- (C) 2024 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "ntop_utils"
local ts_utils = require("ts_utils")
local rest_utils = require("rest_utils")

local info = ntop.getInfo()
local prefs = ntop.getPrefs()

-- Determine release tier as a plain string (no HTML)
local release
if info.oem or info["version.nedge_edition"] then
   release = ""
elseif info["version.enterprise_xxxl_edition"] then
   release = "Enterprise XXXL"
elseif info["version.enterprise_xxl_edition"] then
   release = "Enterprise XXL"
elseif info["version.enterprise_xl_edition"] then
   release = "Enterprise XL"
elseif info["version.enterprise_l_edition"] then
   release = "Enterprise L"
elseif info["version.enterprise_m_edition"] then
   release = "Enterprise M"
elseif info["version.enterprise_edition"] or info["version.nedge_enterprise_edition"] then
   release = "Enterprise"
elseif info["pro.release"] then
   release = "Professional"
else
   release = "Community"
end

if not isEmptyString(release) and info["version.embedded_edition"] then
   release = release .. " (Embedded)"
end

-- Parse nDPI version into structured components
local ndpi = nil
if info["version.ndpi"] then
   local v = string.split(info["version.ndpi"], " ")
   if v and v[2] then
      local v_all = string.sub(v[2], 2, -2)
      local vers = string.split(v_all, ":")
      ndpi = {
         version = v[1],
         commit  = vers[1],
         date    = vers[2],
      }
   else
      ndpi = { version = info["version.ndpi"] }
   end
end

-- Parse git commit hash (strip branch prefix if present)
local git_commit = nil
if info["version.git"] then
   local vers = string.split(info["version.git"], ":")
   if vers and vers[2] then
      git_commit = vers[2]
   end
end

local res = {
   product      = info.product,
   copyright    = info.copyright,
   version      = info.version,
   revision     = info.revision,
   release      = release,
   os           = info.OS,
   platform     = info.platform,
   bits         = info.bits,
   jemalloc     = (info.jemalloc ~= nil),
   hw_model     = info.hw_model,
   command_line = info.command_line,
   zoneinfo     = info.zoneinfo,
   system_id    = info["pro.systemid"],

   max_num_hosts = prefs.max_num_hosts,
   max_num_flows = prefs.max_num_flows,

   -- Component versions
   ndpi          = ndpi,
   version_curl  = info["version.curl"],
   version_rrd   = info["version.rrd"],
   version_nindex = info["version.nindex"],
   version_redis = info["version.redis"],
   version_httpd = info["version.httpd"],
   version_lua   = info["version.lua"],
   version_zmq   = info["version.zmq"],
   version_geoip = info["version.geoip"],

   -- Git reference
   git_commit = git_commit,

   -- Timeseries driver info
   ts_driver             = ts_utils.getDriverName(),
   has_high_resolution_ts = hasHighResolutionTs(),
}

rest_utils.answer(rest_utils.consts.success.ok, res)
