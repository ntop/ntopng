--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local host_pools_nedge = require "host_pools_nedge"

local prefs = ntop.getPrefs()

local captive_portal_utils = {}

-- ##############################################

function captive_portal_utils.is_logged(ip)
   local member = ip

   interface.select("0")
   local host_info = interface.getHostInfo(member)
   if not host_info then
      return false
   end

   local pool_id = host_info.host_pool_id
   if pool_id == host_pools_nedge.DEFAULT_POOL_ID then
tprint(pool_id)
      -- already logged out
      return false
   end

   return true
end

-- ##############################################

function captive_portal_utils.logout(ip)
   local member = ip

   interface.select("0")
   local host_info = interface.getHostInfo(member)
   if not host_info then
      return
   end

   local pool_id = host_info.host_pool_id

   if pool_id == host_pools_nedge.DEFAULT_POOL_ID then
      -- already logged out
      return
   end

  if prefs.is_mac_based_captive_portal then
    member = host_info.mac
    if not member then
       return -- unable to find mac
    end
  end

  host_pools_nedge.deletePoolMemberFromAllPools(member)
  ntop.reloadHostPools()
end

-- ##############################################

function captive_portal_utils.get_style()
return [[
<style type="text/css">
   body {
        padding-top: 40px;
        padding-bottom: 40px;
        background-color: #f5f5f5;
   }

   .form-signin {
        max-width: 400px;
        padding: 9px 29px 29px;
        margin: 0 auto 20px;
        background-color: #fff;
        border: 1px solid #e5e5e5;
        -webkit-border-radius: 5px;
           -moz-border-radius: 5px;
                border-radius: 5px;
          -webkit-box-shadow: 0 1px 2px rgba(0,0,0,.05);
       -moz-box-shadow: 0 1px 2px rgba(0,0,0,.05);
      box-shadow: 0 1px 2px rgba(0,0,0,.05);
   }

   .form-signin .form-signin-heading,
   .form-signin .checkbox {
        margin-bottom: 10px;
   }
   .form-signin input[type="text"],
   .form-signin input[type="password"] {
        font-size: 16px;
        height: auto;
        margin-bottom: 15px;
        padding: 7px 9px;
   }

</style>
]]
end

-- ##############################################

function captive_portal_utils.print_header()
  sendHTTPContentTypeHeader('text/html')

  page_utils.print_header_minimal()

  print [[<div class="container-narrow">]]
  print(captive_portal_utils.get_style())
  print [[<div class="container">]]
end

-- ##############################################

function captive_portal_utils.print_footer()
  print [[</div> <!-- /container -->

  </body>
  </html>]]
end

-- ##############################################

return captive_portal_utils
