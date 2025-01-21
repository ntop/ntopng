--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require "template_utils"
local json = require "dkjson"
local auth = require "auth"
local os_utils = require("os_utils")

-- interface.select(ifname)
local ifid = interface.getId()
local ifstats = interface.getStats()

-- ######################################

local template = _GET["template"]
local view = _GET["view"]

-- ######################################

local infrastructure_view = view and view == 'infrastructure' and ntop.isEnterpriseM() 

local is_system_interface = page_utils.is_system_view()
if is_system_interface and not infrastructure_view then
  print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/system_stats.lua"))
  return
end

-- ######################################

if ntop.isnEdge() or ntop.isAppliance() then
  local sys_config
  local first_start_page

  if ntop.isnEdge() then
    package.path = dirs.installdir .. "/pro/scripts/lua/nedge/modules/system_config/?.lua;" .. package.path
    sys_config = require("nf_config"):create()
    first_start_page = "interfaces.lua"
  else -- ntop.isAppliance()
    package.path = dirs.installdir .. "/scripts/lua/modules/system_config/?.lua;" .. package.path
    sys_config = require("appliance_config"):create()
    first_start_page = "mode.lua"
  end

  if sys_config.isFirstStart() then
    print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/system_setup_ui/"..first_start_page))
    return
  end
end

-- ######################################

if interface.isPcapDumpInterface() then
  -- it doesn't make sense to show the dashboard for pcap files...
  print(ntop.httpRedirect(ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..getInterfaceId(ifname)))
  return
end

-- ######################################

sendHTTPContentTypeHeader('text/html')

-- ######################################

local default_template = "community"

if ntop.isnEdge() then
  if ntop.isnEdgeEnterprise() then
    default_template = "nedge-enterprise"
  else
    default_template = "nedge"
  end
else
  if ntop.isEnterprise() then
    if ntop.isClickHouseEnabled() and auth.has_capability(auth.capabilities.historical_flows) then
      default_template = "enterprise-with-db"
    else
      default_template = "enterprise"
    end
  elseif ntop.isPro() then
    default_template = "pro"
  end
end

template = template or default_template

if infrastructure_view then
  template = "infrastructure"
end

-- ######################################

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.traffic_dashboard)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ######################################

local context = {
  ifid = ifid,
  page = "dashboard",
  template = template,
  is_infrastructure = infrastructure_view,
  csrf = ntop.getRandomCSRFValue(),
  template_endpoint = ntop.getHttpPrefix() .. "/lua/rest/v2/get/dashboard/template/data.lua",
  template_list_endpoint = ntop.getHttpPrefix() .. "/lua/rest/v2/get/dashboard/template/list.lua"
}
   
local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", { vue_page_name = "Dashboard", page_context = json_context })

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
