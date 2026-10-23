
--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "http_lint"
local rest_utils = require "rest_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}
local customer_asn = _POST["customer_asn"]
local sub_customer_asn = _POST["sub_customer_asn"]
local remote_asn = _POST["remote_asn"]

if customer_asn then
   ntop.setCache("ntopng.prefs.config_customer_asn_list", customer_asn)
end

if sub_customer_asn then
   ntop.setCache("ntopng.prefs.config_sub_customer_asn_list", sub_customer_asn)
end

if remote_asn then
   ntop.setCache("ntopng.prefs.config_remote_asn_list", remote_asn)
end

ntop.reloadASNConfiguration()

rest_utils.answer(rest_utils.consts.success.ok, res)
