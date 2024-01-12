--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path

-- ##############################################

local backup_config = require("backup_config")
local rest_utils = require("rest_utils")

-- ##############################################

local rc = rest_utils.consts.success.ok

local order = _GET["order"] or "desc"

local epoch_list = backup_config.list_backup(_SESSION["user"], order)

if epoch_list then
  local extra_rsp_data = {
    ["recordsFiltered"] = tonumber(#epoch_list),
    ["recordsTotal"] = tonumber(#epoch_list)
  }

  rest_utils.extended_answer(rc, epoch_list, extra_rsp_data) 
end

-- ##############################################
