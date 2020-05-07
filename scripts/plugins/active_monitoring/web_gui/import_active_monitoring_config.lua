--
-- (C) 2019-20 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local json = require ("dkjson")
local page_utils = require("page_utils")
local plugins_utils = require("plugins_utils")
local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

local json = require ("dkjson")

if not haveAdminPrivileges() then
   sendHTTPContentTypeHeader('text/html')

   page_utils.print_header()
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
   print("<div class=\"alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>"..i18n("error_not_granted").."</div>")
  return
end

local result = {}

sendHTTPContentTypeHeader('application/json')

-- ################################################

if(_POST["JSON"] == nil) then
  result.error = "invalid-parameter"
  print(json.encode(result))
  return
end

local data = json.decode(_POST["JSON"])

if(table.empty(data)) then
  result.error = "bad-format"
  print(json.encode(result))
  return
end

-- ################################################

local old_hosts = am_utils.getHosts(true --[[ config only ]])

for host_key, conf in pairs(data) do
  -- TODO Validate the configuration
  local host = am_utils.key2host(host_key)

  if old_hosts[host_key] then
    am_utils.editHost(host.host, host.measurement, conf.threshold, conf.granularity)
  else
    am_utils.addHost(host.host, host.measurement, conf.threshold, conf.granularity)
  end
end

-- ################################################

if result.error == nil then
   result.success = true
end

print(json.encode(result))
