--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path


require "lua_utils"
local page_utils = require "page_utils"
local ui_utils = require "ui_utils"
local json = require "dkjson"
local template_utils = require "template_utils"
local alert_entities = require "alert_entities"

local host_pools              = require "host_pools"

-- *************** end of requires ***************

local is_nedge = ntop.isnEdge()

-- select the default page
local page = _GET["page"] or 'host'

sendHTTPContentTypeHeader('text/html')

if not isAdministratorOrPrintErr() then return end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.host_pools)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/admin/manage_pools.lua"
page_utils.print_navbar(i18n("pools.pools"), url, {
    {
        active = true,
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    }
})

-- ************************************* ------

local ALL_POOL_GET_ENDPOINT = '/lua/rest/v2/get/pools.lua'

local pool_types = {
   ["host"] = host_pools,
}

local pool_instance = (page ~= 'all' and pool_types[page]:create() or {})
local pool_type = page

local menu = {
   entries = {
      -- Pools
      { key = "host", title = i18n(alert_entities.host.i18n_label), url = "?page=host", hidden = false},

      -- All Pool (Hidden as we only have the host pool now)
      -- { key = "all", title = i18n("pools.pool_names.all"), url = "?page=all", hidden = false},
   },
   current_page = page
}

local pool_families = {}
for _, entry in ipairs(menu.entries) do
   pool_families[entry.key] = entry.title
end

local rest_endpoints = {
   get_all_pools  = (page == "all" and ALL_POOL_GET_ENDPOINT or string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/get/%s/pools.lua", pool_type)),
   add_pool       = string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/add/%s/pool.lua", pool_type),
   edit_pool      = string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/edit/%s/pool.lua", pool_type),
   delete_pool    = string.format(ntop.getHttpPrefix() .. "/lua/rest/v2/delete/%s/pool.lua", pool_type),
}

local context = {
    template_utils = template_utils,
    json = json,
    menu = menu,
    ui_utils = ui_utils,
    is_nedge = is_nedge,
    pool = {
        name = page,
        pool_families = pool_families,
        is_all_pool = (page == "all"),
        instance = pool_instance,
        all_members = (page ~= "all" and pool_instance:get_all_members() or {}),
        assigned_members = (page ~= "all" and pool_instance:get_assigned_members() or {}),
        endpoints = rest_endpoints,
    }
}

print(template_utils.gen("pages/table_pools.template", context))
-- ************************************* ------

-- append the menu down below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
