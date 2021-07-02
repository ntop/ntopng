--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local host_pools = require "host_pools"

local host_pool = host_pools:create()
local all_pools = host_pools:get_all_pools()
local pool_id_get = _GET["pool"]
local current_pool_name = ""

if pool_id_get then
   pool_id_get = tonumber(pool_id_get)

   for _, p in pairs(all_pools) do
      if p.pool_id == pool_id_get then
         current_pool_name = p.name
      end
   end
end

-- if the _GET["pool"] is not defined then show the first host pool in the page
-- otherwise it means there are no host pools and then show an alert
if #all_pools > 1 and pool_id_get == nil then
   pool_id_get = all_pools[2].pool_id
elseif #all_pools == 0 then
   pool_id_get = 0
end

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then return end
page_utils.set_active_menu_entry(page_utils.menu_entries.host_members)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/admin/manage_host_members.lua"
page_utils.print_navbar(i18n("host_pools.host_members"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})

-- ************************************* ------

local context = {
    template_utils = template_utils,
    json = json,
    pool = host_pool,
    manage_host_members = {
       pool_id_get = pool_id_get,
       current_pool_name = current_pool_name,
       all_pools = all_pools,
       all_policies = all_policies,
       old_policy_name = "Test policy"
    },
}

print(template_utils.gen("pages/manage_host_members.template", context))

-- ************************************* ------

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
