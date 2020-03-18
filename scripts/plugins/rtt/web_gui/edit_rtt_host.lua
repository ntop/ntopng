--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local rtt_utils = require("rtt_utils")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local action = _POST["action"]
local host = _POST["rtt_host"]

local rv = {
  success = false,
}

if isEmptyString(action) then
  print(json.encode({
    error = "Something went wrong. Try again.",
    success = false
  }))
  return
end

if isEmptyString(host) then
  print(json.encode({
    error = "Missing 'host' parameter",
    success = false
  }))
  return
end

if not haveAdminPrivileges() then
  print(json.encode({
    error = "Not admin",
    success = false
  }))
  return
end

-- ################################################

local host_label = rtt_utils.unescapeRttHost(host)

if(action == "add") then
  local existing = rtt_utils.hasHost(host)
  local rtt_value = _POST["rtt_max"] or 500

  if existing then
    rv.error = i18n("rtt_stats.host_exists", {host=host_label})
  else
    rtt_utils.addHost(host, rtt_value)
    rv.success = true
    rv.message = "The host was successful added!"
  end
elseif(action == "edit") then
  local existing = rtt_utils.hasHost(host)

  if not existing then
    rv.error = i18n("rtt_stats.host_not_exists", {host=host_label})
  else
    local rtt_value = _POST["rtt_max"] or 500

    rtt_utils.addHost(host, rtt_value)
    rv.success = true
    rv.message = "The host was successful edited!"
  end
elseif(action == "delete") then
  local existing = rtt_utils.hasHost(host)

  if not existing then
    rv.error = i18n("rtt_stats.host_not_exists", {host=host_label})
  else
    rtt_utils.deleteHost(host)
    rv.success = true
    rv.message = "The host was successful deleted!"
  end
else
  print(json.encode({
    error = "Bad action paramater",
    success = false
  }))
  return
end

-- ################################################

rv.csrf = ntop.getRandomCSRFValue()
print(json.encode(rv))
