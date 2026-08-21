--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local delete_data_utils = require "delete_data_utils"

--
-- Request a full purge of ClickHouse and/or the data directory (RRDs etc.).
-- Actual deletion is performed at the next restart in boot.lua as data is currently in use.
--
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"clickhouse":"1","datadir":"1"}' http://localhost:3000/lua/rest/v2/delete/system/all_data.lua
--

local rc = rest_utils.consts.success.ok
local res = {}

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local purge_clickhouse = toboolean(_POST["clickhouse"])
local purge_datadir    = toboolean(_POST["datadir"])

if not purge_clickhouse and not purge_datadir then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

if purge_clickhouse then
   delete_data_utils.request_purge_all_clickhouse_data()
   res.clickhouse = true
end

if purge_datadir then
   delete_data_utils.request_purge_all_datadir_data()
   res.datadir = true
end

rest_utils.answer(rc, res)
