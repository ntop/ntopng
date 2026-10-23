--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local auth       = require "auth"

--
-- Returns the URL of every REST v2 endpoint installed, to show in the REST API
-- page (Developer > REST API) also the endpoints missing from the OpenAPI spec.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/rest_endpoints.lua
--

if not auth.has_capability(auth.capabilities.developer) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local is_nedge = ntop.isnEdge and ntop.isnEdge()
local res = {}

-- Endpoint files below `dir`, as URLs below `url`
local function listEndpoints(dir, url)
   for name in pairs(ntop.readdir(dir) or {}) do
      local path = dir .. "/" .. name

      if name:sub(-4) == ".lua" then
         res[#res + 1] = url .. "/" .. name
      elseif (name:sub(1, 1) ~= ".") and ntop.isdir(path)
         -- nEdge endpoints only on nEdge
         and (is_nedge or (name ~= "nedge")) then
         listEndpoints(path, url .. "/" .. name)
      end
   end
end

listEndpoints(dirs.installdir .. "/scripts/lua/rest/v2", "/lua/rest/v2")

if ntop.isPro() then
   listEndpoints(dirs.installdir .. "/pro/scripts/lua/rest/v2", "/lua/pro/rest/v2")
end

table.sort(res)

rest_utils.answer(rest_utils.consts.success.ok, res)
