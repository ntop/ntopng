--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path

-- ##############################################

local rest_utils = require("rest_utils")
local backup_config = require("backup_config")

-- ##############################################

local download = _GET["download"]
local epoch = _GET["epoch"]

local resp = backup_config.export_backup(epoch)

if ( resp == -1 ) then
  rest_utils.answer( rest_utils.consts.err.bad_content)
end 

if download and not isEmptyString(download) and download == "true" then
      -- Download as file

  sendHTTPContentTypeHeader('application/json', 'attachment; filename="configuration.json"')
  print(resp)
else

    -- Send as REST answer
    rest_utils.answer(rest_utils.consts.success.ok, resp)
end


-- ##############################################
