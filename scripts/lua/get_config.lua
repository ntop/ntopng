--
-- (C) 2013-18 - ntop.org
--

local prefs = ntop.getPrefs()
local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local os_utils = require "os_utils"

require "lua_utils"
local json = require("dkjson")

local function send_error(error_type)
   local msg = i18n("error")
   if error_type == "not_granted" then
     msg = i18n("conf_backup.not_granted")
   elseif error_type == "tar_not_found" then
     msg = i18n("conf_backup.tar_not_counf")
   end

   sendHTTPContentTypeHeader('application/json')
   print(json.encode({error = msg}))
end

local function starts_with(str, start_str)
   return string.sub(str, 1, string.len(start_str)) == start_str
end

if not isAdministrator() then
  send_error("not_granted")
else

  if ntop.isWindows() then

    sendHTTPContentTypeHeader('application/json', 'attachment; filename="runtimeprefs.json"')

    local runtimeprefs_path = os_utils.fixPath(dirs.workingdir.."/runtimeprefs.json")
    local runtimeprefs = io.open(runtimeprefs_path, "r")
    
    print(runtimeprefs:read "*a") 

  else -- Unix
    local manage_config = "/usr/bin/ntopng-utils-manage-config"
    if not ntop.exists(manage_config) then
      manage_config = os_utils.fixPath(dirs.installdir..'/httpdocs/misc/ntopng-utils-manage-config')
    end

    if not ntop.exists(manage_config) then
      send_error("tar_not_found")
    else

    local tar_file = "ntopng_conf_backup.tar.gz"
    if ntop.isnEdge() then
       tar_file = "nedge_conf_backup.tar.gz"
    end

    local output_tar = os_utils.fixPath(dirs.workingdir.."/"..tar_file)
    local cmd = string.format("%s -a backup -c %s -d %s > /dev/null", manage_config, output_tar, dirs.workingdir)

    -- Note: we are using os.execute / ntop.dumpBinaryFile as io.popen / print 
    -- cannot be used for dumping binary files directly to the connection

    os.execute(cmd)

    if ntop.exists(output_tar) then
       sendHTTPContentTypeHeader('application/x-tar-gz', 'attachment; filename="' .. tar_file .. '"')
       ntop.dumpBinaryFile(output_tar)
       os.remove(output_tar)
    else
       send_error("tar_not_found")
    end
  end
 end
end
