--
-- (C) 2021 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"

local as_utils = {}

local function parseASNList(string)
   local asn = {}
   local tmp = split(string, ",")
   for _, val in pairs(tmp or {}) do
      asn[val] = 1
   end
   return asn
end

function as_utils.getCustomerASNList()
   return ntop.getCache("ntopng.prefs.config_customer_asn_list") or ""
end

function as_utils.getSubCustomerASNList()
   return ntop.getCache("ntopng.prefs.config_sub_customer_asn_list") or ""
end

function as_utils.getRemoteASNList()
   return ntop.getCache("ntopng.prefs.config_remote_asn_list") or ""
end

function as_utils.getCustomerASNs()
   return parseASNList(as_utils.getCustomerASNList())
end

function as_utils.getSubCustomerASNs()
   return parseASNList(as_utils.getSubCustomerASNList())
end

function as_utils.getRemoteASNs()
   return parseASNList(as_utils.getRemoteASNList())
end

function as_utils.getAllConfigurations()
   local customer_asn = as_utils.getCustomerASNs()
   local sub_customer_asn = as_utils.getSubCustomerASNs()
   local remote_asn = as_utils.getRemoteASNs()
   return customer_asn, sub_customer_asn, remote_asn
end

function as_utils.getASNConfiguration(asn)
    local res = nil
    local customer_asn, sub_customer_asn, remote_asn = as_utils.getAllConfigurations()
    if customer_asn[asn] ~= nil then
        res = "customer_asn"
    elseif sub_customer_asn[asn] ~= nil then
        res = "sub_customer_asn" 
    elseif remote_asn[asn] ~= nil then 
        res = "remote_asn"
    end
    return res
end

function as_utils.getCustomerAndSubCustomerASNs()
    local res = {}
    local sub_customer_asns = as_utils.getSubCustomerASNs()
    local my_asns = as_utils.getCustomerASNs()
    for k, v in pairs(sub_customer_asns) do
        res[k] = v
    end
    for k, v in pairs(my_asns) do
        res[k] = v
    end
    return res
end

return as_utils
