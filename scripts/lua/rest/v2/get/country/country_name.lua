--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local country_codes = require "country_codes"

--
-- Read all the  L4 protocols
-- Example: curl -u admin:admin -H "Content-Type: application/json" http://localhost:3000/lua/rest/v2/get/l4/protocol/consts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local country_id = _GET["country_id"]

local country_code = interface.convertCountryU162Code(country_id)
local label = country_code
local rc = rest_utils.consts.success.ok

if country_codes[country_code] then
  label = country_codes[country_code]
end

rest_utils.answer(rc, label)
