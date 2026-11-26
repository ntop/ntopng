--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils" -- isAdministrator()
local rest_utils = require "rest_utils"
local as_utils = require "as_utils"

--
-- The ASN lists of Admin > Network Configuration > ASN Configuration, one entry per
-- list (as_utils.asn_lists)
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/asn/config.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}

for _, list in ipairs(as_utils.asn_lists) do
   res[#res + 1] = {
      key = list.key,
      group = list.group,
      value_description = ntop.getCache(list.redis_key) or "",
      i18n_title = list.i18n_title,
      i18n_description = list.i18n_description,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, res)
