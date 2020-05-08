--
-- (C) 2017-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local info = ntop.getInfo() 

sendHTTPHeader('application/json')

if not haveAdminPrivileges() then
  return
end

local new_version_available_key = "ntopng.updates.new_version"
local check_for_updates_key = "ntopng.updates.check_for_updates"
local upgrade_request_key = "ntopng.updates.run_upgrade"
local upgrade_failure_key = "ntopng.updates.upgrade_failure"

function version2number(v, rev)
  if v == nil then
    return 0
  end

  local e = string.split(v, "%.");

  if e == nil then
    return 0
  end

  local major = e[1]
  local minor = e[2]

  if major == nil or tonumber(major) == nil then major = 0 end
  if minor == nil or tonumber(minor) == nil then minor = 0 end
  if rev   == nil or tonumber(rev)   == nil then rev = 0   end

  local version = tonumber(major)*1000000 + tonumber(minor)*10000 + tonumber(rev)

  return version
end

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

    -- Checking if current version is < available version (to handle manual updates)
    local curr_version = version2number(info["version"], info["revision"])
    local new_version_spl = string.split(new_version, "-");
    if new_version_spl ~= nil then
      local avail_version = version2number(new_version_spl[1], new_version_spl[2])
      if avail_version > curr_version then
        status = "update-avail"
        local upgrade_failure = ntop.getCache(upgrade_failure_key)
        if not isEmptyString(upgrade_failure) then
          status = upgrade_failure
        end
      end
    end
  end
end

res = { 
  status = status, 
  version = new_version,
}

print(json.encode(res, nil, 1))
