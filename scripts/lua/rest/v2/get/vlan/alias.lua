--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

--
-- Alias of a VLAN ("" when not set)
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/vlan/alias.lua?vlan=10"
--

local vlan_id = tonumber(_GET["vlan"])

if not vlan_id or vlan_id <= 0 then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

-- Same hash as label_utils.getVlanAliasKey
local alias = ntop.getHashCache("ntopng.vlan_aliases", tostring(vlan_id)) or ""

rest_utils.answer(rest_utils.consts.success.ok, (alias ~= tostring(vlan_id)) and alias or "")
