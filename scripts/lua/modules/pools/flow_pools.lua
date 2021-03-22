--
-- (C) 2017-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
if ntop.isPro() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

local pools = require "pools"

local flow_pools = {}

-- ##############################################

function flow_pools:create()
   -- Instance of the base class
   local _flow_pools = pools:create()

   -- Subclass using the base class instance
   self.key = "flow"
   -- self is passed as argument so it will be set as base class metatable
   -- and this will actually make it possible to override functions
   local _flow_pools_instance = _flow_pools:create(self)

   -- Return the instance
   return _flow_pools_instance
end

-- ##############################################

-- @brief Given a member key, returns a table of member details such as member name.
--        POOL WITH NO MEMBERS
function flow_pools:get_member_details(member) return {} end

-- ##############################################

-- @brief Returns a table of all possible ids, both assigned and unassigned to pool members
--        POOL WITH NO MEMBERS
function flow_pools:get_all_members() return {} end

-- ##############################################

--@brief Tells the C++ core about the flow recipients
function flow_pools:set_flow_recipients(recipients)
   -- Create a bitmap of all recipients responsible for flows (pool_id in this case is ignored)
   local recipients_bitmap = 0

   for _, recipient_id in ipairs(recipients) do
      recipients_bitmap = recipients_bitmap | (1 << recipient_id)
   end

   -- Tell the C++ that flow recipients have changed
   ntop.recipient_set_flow_recipients(recipients_bitmap)
end

-- ##############################################

--@brief Method called after a successful execution of method persist
function flow_pools:_post_persist(pool_id, name, members, recipients)
   self:set_flow_recipients(recipients)
end

-- ##############################################

function flow_pools:default_only()
   -- This is a dummy, default-only pool
   return true
end

-- ##############################################

return flow_pools
