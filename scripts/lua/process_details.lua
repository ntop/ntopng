--
-- (C) 2019-26 - ntop.org
--
-- The flows of a process are Live Flows filtered by it: links to this page keep working
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"

local params = { ifid = _GET["ifid"], pid_name = _GET["pid_name"] }
local host = _GET["host"]
if host and host ~= "" then
   local vlan = tonumber(_GET["vlan"]) or 0
   params.host = (vlan > 0) and (host .. "@" .. vlan) or host
end

-- Values checked by http_lint (host, numeric ifid, single word pid_name); httpRedirect
-- refuses "%" in the URL, so they are not percent-encoded
local query = {}
for k, v in pairs(params) do
   if v and v ~= "" then query[#query + 1] = k .. "=" .. tostring(v) end
end

print(ntop.httpRedirect(ntop.getHttpPrefix() .. "/lua/flows_stats.lua?" .. table.concat(query, "&")))
