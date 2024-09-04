
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local json = require "dkjson"

local action = _GET["action"]
local post_data = _POST["payload"]

local res = {}

local payload = _POST["payload"]
local data = json.decode(payload)

for k,v in pairs(data.config) do
   ntop.setCache("ntopng.prefs.nw_config_".. v.key, v.value)
end

rest_utils.answer(rest_utils.consts.success.ok, res)
