--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local host_pools = require "host_pools"
local json = require "dkjson"
local rest_utils = require("rest_utils")
local radius_handler = require "radius_handler"

sendHTTPContentTypeHeader('application/json')

--[[ 
   Request example:
   curl -u admin:admin -H "Content-Type: application/json" -d '{"associations" : {"DE:AD:BE:EE:FF:FF" : {"group" : "staff", "connectivity" : "pass", "username" : "gio", "password" : "XXX"},"AB:AB:AB:AB:AB:AB" : {"group" : "guest", "connectivity" : "reject", "username" : "john", "password" : "XXX"},"192.168.2.221/32@0" : {"group" : "staff", "connectivity" : "pass", "username" : "joseph", "password" : "XXX"}}}' http://192.168.1.1:3000/lua/rest/v2/set/pool/members.lua 

   Data example:
   local res = {
     associations = {
       ["DE:AD:BE:EE:FF:FF"] = {
         group = "staff", 
         connectivity = "pass",
         username: "905395124062",
         password: "XXX",
       },
       ["AB:AB:AB:AB:AB:AB"] = {
         group = "guest", 
         connectivity = "reject"
         username: "905395124063",
         password: "XXX",
       },
       ["192.168.2.221/32@0"] = {
         group = "staff", 
         connectivity = "reject"
         username: "905395124064",
         password: "XXX",
       }
     }
   }
--]]

local rc = rest_utils.consts.success.ok

-- Instantiate host pools
local s = host_pools:create()

local r = {}

local pools_list = {}

-- Table with pool names as keys
for _, pool in pairs(s:get_all_pools()) do
    pools_list[pool["name"]] = pool
end

local res = {
    associations = _POST["associations"]
}

for member, info in pairs(_POST["associations"] or {}) do

    if member == nil then
        res["associations"][member]["status"] = "ERROR"
        res["associations"][member]["status_msg"] = "Bad member format"
        goto continue
    end

    local pool = info["group"]

    if pools_list[pool] == nil then
        res["associations"][member]["status"] = "ERROR"
        res["associations"][member]["status_msg"] = "Unable to find a group with the specified name"
        goto continue
    end

    local pool_id = pools_list[pool]["pool_id"]
    local connectivity = info["connectivity"]
    local username = info["username"]
    local password = info["password"]

    if connectivity == "pass" then
        if s:bind_member(member, pool_id) == true then
            res["associations"][member]["status"] = "OK"
            radius_handler.accountingStart(member, username, password)
        else
            res["associations"][member]["status"] = "ERROR"
            res["associations"][member]["status_msg"] = "Failure adding member, maybe bad member MAC or IP"
        end
    elseif info["connectivity"] == "reject" then
        s:bind_member(member, host_pools.DEFAULT_POOL_ID)
        res["associations"][member]["status"] = "OK"
        radius_handler.accountingStop(member)
    else
        res["associations"][member]["status"] = "ERROR"
        res["associations"][member]["status_msg"] = "Unknown association: allowed associations are 'pass' and 'reject'"
    end

    ::continue::
end

rest_utils.answer(rc, res)

