--
-- (C) 2013-26 - ntop.org
--
-- Thin shell: emits JS globals block required by legacy page scripts,
-- then mounts AppShell (sidebar + topbar combined) Vue component.
-- All menu/topbar data is fetched by Vue from GET /lua/rest/v2/get/ntopng/menu.lua
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require "lua_utils"

local page_utils     = require "page_utils"
local toasts_manager = require "toasts_manager"
local template_utils = require "template_utils"
local json           = require "dkjson"

local is_admin            = isAdministrator()
local session_user        = _SESSION["user"]
local interface_id        = interface.getId()
if _GET["ifid"] and tostring(_GET["ifid"]) ~= tostring(interface_id) then
   interface_id = tonumber(_GET["ifid"]) or interface_id
end
local random_csrf         = ntop.getRandomCSRFValue()
local is_system_interface = toboolean(page_utils.is_system_view())
local http_prefix         = ntop.getHttpPrefix()

-- JS globals — consumed by legacy page scripts before Vue mounts
print("<div class='wrapper'>")

print [[
<script type='text/javascript'>

   const isAdministrator = ]]
print(is_admin)
print [[;
   const loggedUser = "]]
print(session_user)
print [[";
   const interfaceID = ]]
print(interface_id)
print [[;

   const i18n_ext = {
      "no_results_found": "]]
print(i18n("no_results_found"))
print [[",
      "are_you_sure": "]]
print(i18n("scripts_list.are_you_sure"))
print [[",
      "change_number_of_rows": "]]
print(i18n("change_number_of_rows"))
print [[",
      "no_data_available": "]]
print(i18n("no_data_available"))
print [[",
      "showing_x_to_y_rows": "]]
print(i18n("showing_x_to_y_rows", { x = "{0}", y = "{1}", tot = "{2}" }))
print [[",
      "actions": "]]
print(i18n("actions"))
print [[",
      "query_was_aborted": "]]
print(i18n("graphs.query_was_aborted"))
print [[",
      "exports": "]]
print(i18n("system_stats.exports_label"))
print [[",
      "no_file": "]]
print(i18n("config_scripts.no_file"))
print [[",
      "invalid_file": "]]
print(i18n("config_scripts.invalid_file"))
print [[",
      "request_failed_message": "]]
print(i18n("request_failed_message"))
print [[",
      "all": "]]
print(i18n("all"))
print [[",
      "edit": "]]
print(i18n("edit"))
print [[",
      "remove": "]]
print(i18n("remove"))
print [[",
      "and": "]]
print(i18n("and"))
print [[",
      "other": "]]
print(i18n("other"))
print [[",
      "others": "]]
print(i18n("others"))
print [[",
      "warning": "]]
print(i18n("warning"))
print [[",
      "search": "]]
print(i18n("search"))
print [[",
      "as": "]]
print(i18n("as"))
print [[",
      "no_recipients": "]]
print(i18n("endpoint_notifications.no_recipients"))
print [[",
      "score": "]]
print(i18n("score"))
print [[",
      "alerted_flows": "]]
print(i18n("flow_details.alerted_flows"))
print [[",
      "blacklisted_flows": "]]
print(i18n("alerts_dashboard.blacklisted_flow"))
print [[",
      "flow_status": "]]
print(i18n("graphs.flow_status"))
print [[",
      "traffic_rcvd": "]]
print(i18n("graphs.traffic_rcvd"))
print [[",
      "traffic_sent": "]]
print(i18n("graphs.traffic_sent"))
print [[",
      "flows": "]]
print(i18n("db_explorer.total_flows"))
print [[",
      "nation": "]]
print(i18n("nation"))
print [[",
      "and_x_more": "]]
print(i18n("and_x_more", { num = "$num" }))
print [[",
      "invalid_input": "]]
print(i18n("validation.invalid_input"))
print [[",
      "missing_field": "]]
print(i18n("validation.missing_field"))
print [[",
      "unreachable_host": "]]
print(i18n("graphs.unreachable_host"))
print [[",
      "NAME_RESOLUTION_FAILED": "]]
print(i18n("rest_consts.NAME_RESOLUTION_FAILED"))
print [[",
      "FAILED_HTTP_REQUEST": "]]
print(i18n("validation.FAILED_HTTP_REQUEST"))
print [[",
      "rest_consts": {
         "PARTIAL_IMPORT": "]]
print(i18n("rest_consts.PARTIAL_IMPORT"))
print [[",
         "CONFIGURATION_FILE_MISMATCH": "]]
print(i18n("rest_consts.CONFIGURATION_FILE_MISMATCH"))
print [[",
      }
   };

   const systemInterfaceEnabled = ]]
print(ternary(is_system_interface, "true", "false"))
print [[;

   window.unchangable_pool_names = ['Jailed Hosts'];
   window.__CSRF_DATATABLE__ = `]]
print(random_csrf)
print [[`;
   window.__BLOG_NOTIFICATION_CSRF__ = `]]
print(random_csrf)
print [[`;

   if (document.cookie.indexOf("tzoffset=") < 0) {
      document.cookie = "tzoffset=" + (new Date().getTimezoneOffset() * 60 * -1);
   }
</script>]]

local boot_context = json.encode({
   csrf               = random_csrf,
   http_prefix        = http_prefix,
   ifid               = tostring(interface_id),
   is_system_interface = is_system_interface,
   is_admin           = is_admin,
   username           = session_user,
   active_section     = page_utils.get_active_section() or "",
   active_entry       = page_utils.get_active_entry()   or "",
})

-- AppShell: sidebar + topbar
template_utils.render("pages/vue_page.template", {
   vue_page_name = "AppShell",
   page_context  = boot_context,
})

-- Open main content area
print("<main id='n-container' class='px-md-4 px-sm-1'>")

toasts_manager.render_toasts("main-container", toasts_manager.load_main_toasts())

print("<div class='main-alerts'>")

print('<div id="influxdb-error-msg" class="alert alert-danger alert-dismissable" style="display:none" role="alert">' ..
   '<i class="fas fa-exclamation-triangle fa-lg"></i> ' ..
   '<span id="influxdb-error-msg-text"></span>' ..
   '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>' ..
   '</div>')

print('<div id="major-release-alert" class="alert alert-info" style="display:none" role="alert">' ..
   '<i class="fas fa-cloud-download-alt"></i> ' ..
   '<span id="ntopng_update_available"></span>' ..
   '</div>')

print("</div>")
