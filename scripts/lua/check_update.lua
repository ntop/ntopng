--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local info = ntop.getInfo() 

sendHTTPHeader('application/json')

if not isAdministratorOrPrintErr() then
  return
end

local new_version_available_key = "ntopng.updates.new_version"
local check_for_updates_key = "ntopng.updates.check_for_updates"
local upgrade_request_key = "ntopng.updates.run_upgrade"
local update_failure_key = "ntopng.updates.update_failure"

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

-- Checking if there is a new version and current version is < available version
local new_version = ntop.getCache(new_version_available_key)
if not isEmptyString(new_version) then
  local curr_version = version2number(info["version"], info["revision"])
  local new_version_spl = string.split(new_version, "-");
  if new_version_spl ~= nil then
    local avail_version = version2number(new_version_spl[1], new_version_spl[2])
    if avail_version <= curr_version then
      new_version = nil
    end
  else
    new_version = nil
  end
end

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
    -- Checking updates
    status = "checking"
  else

    -- Check for failures
    local update_failure = ntop.getCache(update_failure_key)

    -- Allow updates with no license in forced Community mode
    if not isEmptyString(update_failure) then
      if update_failure == "no-license" and ntop.isForcedCommunity() then
        update_failure = nil
      elseif update_failure == "upgrade-failure" and isEmptyString(new_version) then
        update_failure = nil -- Manual update after a failure?
      end
    end

    if not isEmptyString(update_failure) then
      status = update_failure
    else
      -- Check if the availability of a new update has been detected
      if not isEmptyString(new_version) then
        status = "update-avail"
      end
    end
  end
end

res = { 
  status = status, 
  version = new_version,
}

print(json.encode(res, nil, 1))
