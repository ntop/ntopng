--
-- (C) 2017-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")

sendHTTPHeader('application/json')

if not haveAdminPrivileges() then
  return
end

local new_version_available_key = "ntopng.updates.new_version"
local check_for_updates_key = "ntopng.updates.check_for_updates"
local upgrade_request_key = "ntopng.updates.run_upgrade"

local status = "not-avail"
local checking_updates = nil

if _POST["search"] ~= nil then
  ntop.setCache(check_for_updates_key, "1", 600)
  checking_updates = "1"
end

local new_version = ntop.getCache(new_version_available_key)

-- Check if an upgrade has been already requested
local installing = ntop.getCache(upgrade_request_key)
if not isEmptyString(installing) then
  status = "installing"
else

  -- Check if we are currently checking the presence of a new update
  if checking_updates == nil then
    checking_updates = ntop.getCache(check_for_updates_key)
  end
  if not isEmptyString(checking_updates) then
    status = "checking"

  -- Check if the availability of a new update has been detected
  elseif not isEmptyString(new_version) then
    status = "update-avail"
  end
end

res = { 
  status = status, 
  version = new_version,
  csrf = ntop.getRandomCSRFValue()
}

print(json.encode(res, nil, 1))
