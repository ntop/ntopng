--
-- (C) 2013-26 - ntop.org
--
-- Thin shell: closes the page. All footer/global-shell logic (updates,
-- ext_link_dialog, nEdge modals, 403 handler) now lives in AppShell
-- (http_src/vue/app-shell.vue), mounted once by scripts/lua/inc/menu.lua.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local ts_utils = require "ts_utils_core"

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

print("</main>")
print("</div>")
print("</body>")
print("</html>")
