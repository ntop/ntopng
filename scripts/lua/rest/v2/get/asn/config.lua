--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils" -- isAdministrator()
local rest_utils = require "rest_utils"
local as_utils = require "as_utils"

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}

-- Get data from redis: expected format, array of objects with keys: 
res = {
    {
        key = "customer_asn",
        value_description = as_utils.getCustomerASNList()
    }, {
        key = "sub_customer_asn",
        value_description = as_utils.getSubCustomerASNList()
    }, {
        key = "remote_asn",
        value_description = as_utils.getRemoteASNList()
    }
}

rest_utils.answer(rest_utils.consts.success.ok, res)
