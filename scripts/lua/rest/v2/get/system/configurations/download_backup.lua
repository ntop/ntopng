--
-- (C) 2013-24 - ntop.org
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

local success, response = backup_config.export_backup(epoch)

if (not success) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
end

-- Download the file  
if download then
    sendHTTPContentTypeHeader('application/json', 'attachment; filename="ntopng_backup_' .. epoch .. '.json"')
    print(response)
else
    rest_utils.answer(rest_utils.consts.success.ok, rsp)
end
-- ##############################################
