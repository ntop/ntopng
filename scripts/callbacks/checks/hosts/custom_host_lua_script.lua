--
-- (C) 2013-22 - ntop.org
--

--
-- This script is a demo of what ntopng can do when enabling
-- the 'Custom Script Check' behavioural check under the 'Hosts' page
--
-- NOTE: this script is called periodically (i.e. every minute) for every host
--       that ntopng has in memory
--

-- the function below is for *DEBUG ONLY* purposes to test the implementation
function dump_host()
   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
   require "lua_utils"

   local rsp = {}

   rsp.ip                  = host.ip()
   rsp.mac                 = host.mac()
   rsp.name                = host.name()
   rsp.vlan_id             = host.vlan_id()
   rsp.is_unicast          = host.is_unicast()
   rsp.is_multicast        = host.is_multicast()
   rsp.is_broadcast        = host.is_broadcast()
   rsp.is_blacklisted      = host.is_blacklisted()
   rsp.bytes_sent          = host.bytes_sent()
   rsp.bytes_rcvd          = host.bytes_rcvd()
   rsp.bytes               = host.bytes()
   rsp.l7                  = host.l7()

   io.write("----------------------------\n")
   tprint(rsp)
end


-- the function below shows an example of how a host alert is triggered
function trigger_dummy_alert()

   local score   = 100
   local message = "Test for the custom host script"

   host.triggerAlert(score, message)
end

dump_host()

trigger_dummy_alert()

-- Set this host as already visited in case we want to visit it once
-- With this call, a host is visited only once. Do not call the method below
-- if you want to visit the host periodically
host.skipVisitedHost()

-- IMPORTANT: do not forget this return at the end of the script
return(0)
