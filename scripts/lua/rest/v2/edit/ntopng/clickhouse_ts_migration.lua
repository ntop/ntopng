--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local clickhousets = require("clickhousets")

--
-- Move the ClickHouse timeseries table to the entity sort key at the next startup
-- (only a table created before the entity column needs it)
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{}' http://localhost:3000/lua/rest/v2/edit/ntopng/clickhouse_ts_migration.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- _POST is filled only with a valid CSRF
if next(_POST) == nil then
   rest_utils.answer(rest_utils.consts.err.bad_format)
   return
end

if not clickhousets.requestEntityMigration() then
   rest_utils.answer(rest_utils.consts.err.bad_content)
   return
end

rest_utils.answer(rest_utils.consts.success.ok)
