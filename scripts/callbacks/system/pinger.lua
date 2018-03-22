--
-- (C) 2013-18 - ntop.org
--


local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/callbacks/system/?.lua;" .. package.path

if ntop.isnEdge() then
   package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/?.lua;" .. package.path

   require("lua_utils")
   local NfConfig = require("nf_config")

   NfConfig.checkPolicyChange()

   if ntop.isRoutingMode() then
     local ping_utils = require('ping_utils')
     local nf_config = NfConfig:readable()

     nf_config:recheckGatewaysInformationFromSystem()
     ping_utils.check_status(nf_config)
   end
end
