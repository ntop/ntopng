--
-- (C) 2018 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local os_utils = require("os_utils")

local SERVICE_NAME = "n2n"
local N2N_INTERFACE_NAME = "n2n_assistance"
local DEVICE_IP = "192.168.166.1"
local ASSISTANT_IP = "192.168.166.10"
local DEFAULT_SUPERNODE = "supernode.ntop.org:7777"
local CONF_DIR = dirs.workingdir.."/n2n"
local CONF_FILE = CONF_DIR .. "/edge.conf"
local TEMP_ADMIN_PASSWORD_KEY = "ntopng.prefs.temp_admin_password"
local REMOTE_ASSISTANCE_EXPIRATION = 86400 --[[ keep active for max 1 day ]]
local IS_AVAILABLE_KEY = "ntopng.cache.remote_assistance_available"
local remote_assistance = {}

-- ########################################################

function remote_assistance.checkAvailable()
  ntop.setCache(IS_AVAILABLE_KEY, ternary(os_utils.hasService(SERVICE_NAME, N2N_INTERFACE_NAME), "1", "0"))
end

-- ########################################################

function remote_assistance.isAvailable()
  return isAdministrator() and (ntop.getCache(IS_AVAILABLE_KEY) == "1")
end

-- ########################################################

function remote_assistance.enableTempAdminAccess(key)
  ntop.setPref(TEMP_ADMIN_PASSWORD_KEY, key, REMOTE_ASSISTANCE_EXPIRATION) 
end

-- ########################################################

function remote_assistance.disableTempAdminAccess()
  ntop.delCache(TEMP_ADMIN_PASSWORD_KEY)
end

-- ########################################################

local function getUidGid()
  local prefs = ntop.getPrefs()

  if not isEmptyString(prefs.user) then
    -- uid=999(ntopng) gid=999(ntopng) groups=999(ntopng)
    local res = os_utils.execWithOutput("id " .. prefs.user) or ""
    local uid = res:gmatch("uid=(%d+)")()
    local gid = res:gmatch("gid=(%d+)")()

    return uid, gid
  end
end

-- ########################################################

function remote_assistance.createConfig(community, key)
  local supernode = ntop.getPref("ntopng.prefs.remote_assistance.supernode")

  if isEmptyString(supernode) then
    supernode = DEFAULT_SUPERNODE
  end

  if not ntop.mkdir(CONF_DIR) then
    return false
  end

  local f = io.open(CONF_FILE, "w")

  if not f then
    return false
  end

  f:write("-d=".. N2N_INTERFACE_NAME .."\n")
  f:write("-l=".. supernode .."\n")
  f:write("-c=".. community .."\n")
  f:write("-k=".. key .."\n")

  local uid, gid = getUidGid()

  if((uid ~= nil) and (gid ~= nil)) then
    f:write("-u=".. uid .."\n");
    f:write("-g=".. gid .."\n");
  end

  f:write("-a=".. DEVICE_IP .."\n")

  f:close()

  ntop.setPref("ntopng.prefs.remote_assistance.active_supernode", supernode)

  return true
end

-- ########################################################

function remote_assistance.isEnabled()
  return(ntop.getPref("ntopng.prefs.remote_assistance.enabled") == "1")
end

-- ########################################################

function remote_assistance.enableAndStart()
  ntop.setPref("ntopng.prefs.remote_assistance.enabled", "1")
  ntop.setPref("ntopng.prefs.remote_assistance.expires_on", tostring(os.time() + REMOTE_ASSISTANCE_EXPIRATION))
  os_utils.enableService(SERVICE_NAME, N2N_INTERFACE_NAME)
  return os_utils.restartService(SERVICE_NAME, N2N_INTERFACE_NAME)
end

-- ########################################################

function remote_assistance.disableAndStop()
  ntop.delCache("ntopng.prefs.remote_assistance.enabled")
  os_utils.disableService(SERVICE_NAME, N2N_INTERFACE_NAME)
  return os_utils.stopService(SERVICE_NAME, N2N_INTERFACE_NAME)
end

-- ########################################################

function remote_assistance.restart()
  return os_utils.restartService(SERVICE_NAME, N2N_INTERFACE_NAME)
end

-- ########################################################

function remote_assistance.checkExpiration()
  if remote_assistance.isEnabled() then
    local expires_on = tonumber(ntop.getPref("ntopng.prefs.remote_assistance.expires_on"))

    if((expires_on == nil) or (os.time() >= expires_on)) then
      remote_assistance.disableTempAdminAccess()
      remote_assistance.disableAndStop()
    end
  end
end

-- ########################################################

function remote_assistance.getStatus()
  return os_utils.serviceStatus(SERVICE_NAME, N2N_INTERFACE_NAME)
end

-- ########################################################

--! @brief Return the log trace of the remote assistance service (n2n)
--! @param rows the number of lines to return
--| @note lines are retuned in reverse order (most recent line first)
--! @return the log trace
function remote_assistance.log(rows)
  return os_utils.ntopctlCmd(SERVICE_NAME, "log", N2N_INTERFACE_NAME, "|tail -n", rows, "|tac")
end

-- ########################################################

function remote_assistance.getInterfaceName()
  return N2N_INTERFACE_NAME
end

-- ########################################################

function remote_assistance.getIpAddress()
  return DEVICE_IP
end

-- ########################################################

-- Get the active supernode
function remote_assistance.getSupernode()
  local val = ntop.getPref("ntopng.prefs.remote_assistance.active_supernode")

  if not isEmptyString(val) then
    return val
  end

  return DEFAULT_SUPERNODE
end

-- ########################################################

function remote_assistance.getConnectionCommand()
  local community = ntop.getPref("ntopng.prefs.remote_assistance.community")
  local key = ntop.getPref("ntopng.prefs.remote_assistance.key")
  local supernode = remote_assistance.getSupernode()

  -- sudo "n2n " -d $N2N_IFACE -c $N2N_COMMUNITY -k $N2N_KEY -u `id -u` -g `id -g` -a $MY_IP -f -l $N2N_SUPERNODE
  local cmd = {"sudo edge -d ", N2N_INTERFACE_NAME, " -c ", community, " -k ", key, " -u `id -u` -g `id -g` -a ", ASSISTANT_IP, " -f -l ", supernode}
  return table.concat(cmd)
end

-- ########################################################

function remote_assistance.statusLabel()
  local rv = os_utils.serviceStatus(SERVICE_NAME, N2N_INTERFACE_NAME)
  local color
  local status

  if rv == "active" then
    status = i18n("running")
    color = "success"
  elseif rv == "inactive" then
    status = i18n("nedge.status_inactive")
    color = "default"
  else -- error
    status = i18n("error")
    color = "danger"
  end

  return [[<span class="badge badge-]] .. color .. [[">]] .. status ..[[</span>]]
end

-- ########################################################

return remote_assistance
