--
-- (C) 2013-26 - ntop.org
--
-- Thin shell: mounts AppFooter Vue component, then closes the page.
-- All footer logic (updates, ext_link_dialog, nEdge modals, 403 handler)
-- lives in http_src/vue/app-footer.vue.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require "lua_utils"

local template_utils = require "template_utils"
local json           = require "dkjson"
local ts_utils       = require "ts_utils_core"

local is_admin    = isAdministrator()
local have_nedge  = ntop.isnEdge()
local info        = ntop.getInfo(true)
local http_prefix = ntop.getHttpPrefix()
local random_csrf = ntop.getRandomCSRFValue()

-- Show InfluxDB error immediately if one is cached
if ts_utils.getDriverName() == "influxdb" then
   local msg = ntop.getCache("ntopng.cache.influxdb.last_error")
   if not isEmptyString(msg) then
      msg = msg:gsub('"', '\\"')
      print([[<script type="text/javascript">
  document.getElementById("influxdb-error-msg-text").innerHTML = "]] .. msg .. [[";
  document.getElementById("influxdb-error-msg").style.display = "";
</script>]])
   end
end

-- AppFooter boot context
local footer_context = json.encode({
   csrf                = random_csrf,
   http_prefix         = http_prefix,
   ifid                = tostring(interface.getId()),
   is_admin            = is_admin,
   is_nedge            = have_nedge,
   has_updates_support = (hasSoftwareUpdatesSupport() == true),
   is_package          = (ntop.isPackage() == true),
   is_windows          = ntop.isWindows(),
   product             = info.product or "",
   maintenance_expired = (info["pro.license_days_left"] ~= nil and
                          tonumber(info["pro.license_days_left"]) <= 0),
})

template_utils.render("pages/vue_page.template", {
   vue_page_name = "AppFooter",
   page_context  = footer_context,
})

print("</main>")
print("</div>")
print("</body>")
print("</html>")
