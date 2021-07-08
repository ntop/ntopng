--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local auth = require "auth"
local rest_utils = require "rest_utils"
local host_pools = require "host_pools"
local pools_rest_utils = require "pools_rest_utils"

--- Import Host Pool members by reading file content
local pool_id = _POST["pool"]
local members_file_content = _POST["host_pool_members"]

if not auth.has_capability(auth.capabilities.pools) then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

if not pool_id or not members_file_content then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

local s = host_pools:create()
local members = split(members_file_content, "\n")

host_pools:start_transaction()

for _, member in ipairs(members) do
   -- TODO: add the member to the right host pool using pools_rest_utils
   
   -- Expected format
   -- 00:11:22:33:44:55
   -- 192.168.1.10/32@10

   -- Note IPv6 not handled for now
   
   if(member ~= "") then 
      if((not member:find("^%d+%.%d+%.%d+%.%d+"))
	 and (not member:find("^%w+:%w+:%w+:%w+:%w+:%w+:%w+:%w+"))
	 and (not member:find("^%w+:%w+:%w+:%w+:%w+:%w+$"))) then
	 traceError(TRACE_WARNING, TRACE_CONSOLE, "Pool import: skipping "..member)
      else       
	       if(string.find(member, ":") == nil) then
		  -- This is not a MAC address
		  local cidr_idx = string.find(member, "/")
		  if(cidr_idx == nil) then
		     local vlan_idx = string.find(member, "@")
		     if(vlan_idx == nil) then
			member = member.."/32"
		     else
			member = member:sub(0, vlan_idx-1) .."/32"..member:sub(vlan_idx)
		     end
		  end
		  
		  local vlan_idx = string.find(member, "@")
		  if(vlan_idx == nil) then
		     member = member.."@0"
		  end
	       end
	       
	       res,err = s:bind_member_if_not_already_bound(member, pool_id)
	       --ntop.setMembersCache("ntopng.prefs.host_pools.members."..pool_id, member)
      end
   end
end

host_pools:end_transaction()

rest_utils.answer(rest_utils.consts.success.ok)
