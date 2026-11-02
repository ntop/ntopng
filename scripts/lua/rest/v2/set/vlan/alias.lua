--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

--
-- Set the alias of a VLAN; an empty alias removes it. Administrators only
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"vlan": "10", "alias": "Office"}' http://localhost:3000/lua/rest/v2/set/vlan/alias.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local vlan_id = tonumber(_POST["vlan"])
local alias = _POST["alias"]

-- 0 is the untagged traffic: no alias
if not vlan_id or vlan_id <= 0 then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- Same hash as label_utils.getVlanAliasKey
local key = "ntopng.vlan_aliases"
local id = tostring(vlan_id)

if isEmptyString(alias) or alias == id then
   ntop.delHashCache(key, id)
else
   ntop.setHashCache(key, id, alias)
end

rest_utils.answer(rest_utils.consts.success.ok)
