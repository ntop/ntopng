--
-- (C) 2020-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

--
-- Returns license information for the current ntopng instance.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/license.lua
--

if not isAdministratorOrPrintErr() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local info = ntop.getInfo()

-- Determine edition key for the shop URL
local edition
if ntop.isnEdge and ntop.isnEdge() then
   if info["version.nedge_enterprise_edition"] == true then
      if info["version.embedded_edition"] == true then
         edition = "nedge_embedded_ent"
      else
         edition = "nedge_enterprise"
      end
   else
      if info["version.embedded_edition"] == true then
         edition = "nedge_embedded_pro"
      else
         edition = "nedge_pro"
      end
   end
else
   if info["version.embedded_edition"] == true then
      edition = "embedded"
   elseif info["version.enterprise_edition"] == true then
      edition = "enterprise"
   else
      edition = "pro"
   end
end

local version = split(info["version"], " ")
local system_id = info["pro.systemid"]
local system_id_href = nil
if system_id and system_id ~= "" then
   system_id_href = string.format(
      "https://shop.ntop.org/mkntopng?systemid=%s&version=%s&edition=%s",
      system_id, version[1], edition
   )
end

local eula_url = ternary(
   info["pro.release"],
   "https://www.ntop.org/support/faq/what-is-the-end-user-license-agreement-for-binary-products/",
   "http://www.gnu.org/licenses/gpl.html"
)

local res = {
   system_id          = system_id,
   system_id_href     = system_id_href,
   has_valid_license  = info["pro.has_valid_license"],
   license_type       = info["pro.license_type"],
   license_encoded    = info["pro.license_encoded"],
   license_ends_at    = info["pro.license_ends_at"],
   license_days_left  = info["pro.license_days_left"],
   use_redis_license  = info["pro.use_redis_license"],
   is_windows         = ntop.isWindows(),
   eula_url           = eula_url,
   cached_license     = ntop.getCache("ntopng.license"),
}

rest_utils.answer(rest_utils.consts.success.ok, res)