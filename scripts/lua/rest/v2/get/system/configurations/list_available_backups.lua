--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path

-- ##############################################

require "http_lint"   -- validates _GET before it is read
require "ntop_utils"  -- isAdministrator()
local backup_config = require("backup_config")
local rest_utils = require("rest_utils")

-- ##############################################

if not isAdministrator() then
  rest_utils.answer(rest_utils.consts.err.not_granted)
  return
end

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
