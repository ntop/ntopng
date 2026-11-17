--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local host_pools = require "host_pools"
local rest_utils = require("rest_utils")
local radius_handler = require "radius_handler"

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
         terminateCause: "1"
       },
       ["192.168.2.221/32@0"] = {
         group = "staff",
         connectivity = "reject"
         username: "905395124064",
         handle_with_radius: true,
         password: "XXX",
       }
     }
   }
--]]

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local synchronous = toboolean(_POST["sync"])
local rc = rest_utils.consts.success.ok
local host_pools_changed = false

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

  local m = string.upper(member)

  local pool = info["group"]

  if pools_list[pool] == nil then
    res["associations"][m]["status"] = "ERROR"
    res["associations"][m]["status_msg"] = "Unable to find a group with the specified name"
    goto continue
  end

  local pool_id = pools_list[pool]["pool_id"]
  local connectivity = info["connectivity"]
  local username = info["username"]
  local password = info["password"]
  local handle_with_radius = toboolean(info["handle_with_radius"] or false)

  local current_interface = interface.getId() or -1 -- System Interface

  if connectivity == "pass" then
    if s:bind_member(m, pool_id) == true then
      host_pools_changed = true
      res["associations"][m]["status"] = "OK"
      interface.select(tostring(interface.getFirstInterfaceId()))
      if handle_with_radius then
        radius_handler.accountingStart(m, username, password)
      end
      interface.select(current_interface)
    else
      res["associations"][m]["status"] = "ERROR"
      res["associations"][m]["status_msg"] = "Failure adding member, maybe bad member MAC or IP"
    end
  elseif connectivity == "reject" then
    -- To check radius termination cause see https://datatracker.ietf.org/doc/html/rfc2866#section-5.10
    s:bind_member(m, host_pools.DEFAULT_POOL_ID)
    host_pools_changed = true
    res["associations"][m]["status"] = "OK"
    interface.select(tostring(interface.getFirstInterfaceId()))
    local mac_info = interface.getMacInfo(m)
    if handle_with_radius then
      local terminate_cause = info["terminateCause"] or 3     -- Lost service
      radius_handler.accountingStop(m, terminate_cause, mac_info)
    end
    interface.select(current_interface)
  else
    res["associations"][m]["status"] = "ERROR"
    res["associations"][m]["status_msg"] = "Unknown association: allowed associations are 'pass' and 'reject'"
  end

  ::continue::
end

local function get_configured_pool(member)
  local exp_pool = s:get_pool_by_member(member) -- pool on redis
  if exp_pool ~= nil then exp_pool = exp_pool.pool_id end
  return exp_pool
end

local function get_current_pool(member)
  local cur_pool = s:get_pool_id(member) -- pool on backend (updating)
  if cur_pool == 0 then cur_pool = nil end
  return cur_pool
end

if host_pools_changed then
  ntop.reloadHostPools()

  if synchronous then
    -- Wait for the change to be applied (pools reloaded)
    for member, info in pairs(_POST["associations"] or {}) do
      local m = string.upper(member)
      if res["associations"][m]["status"] ~= "ERROR" then
        local max_iterations = 50 -- max 5s
        local iterations = 0
        while get_current_pool(m) ~= get_configured_pool(m) and iterations < max_iterations do
          ntop.msleep(100)
          iterations = iterations + 1
        end
        if iterations >= max_iterations then
          res["associations"][m]["status"] = "ERROR"
          res["associations"][m]["status_msg"] = "Request timed out: pool update is taking too long"
        end
      end
    end
  end

end

rest_utils.answer(rc, res)
