--
-- (C) 2013-21 - ntop.org
--


local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path

if ntop.isnEdge() then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path

   -- Select the NetfilterInterface, as by default the System interface is selected
   interface.select(nil)

   require("lua_utils")
   local nf_config = require("nf_config")

   nf_config.checkPolicyChange()

   if ntop.isRoutingMode() then
     local ping_utils = require('ping_utils')
     local nf_config_instance = nf_config:create()

     nf_config_instance:recheckGatewaysInformationFromSystem()
     ping_utils.check_status(nf_config_instance)
   end
end
