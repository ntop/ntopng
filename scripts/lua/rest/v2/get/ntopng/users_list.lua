--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "ntop_utils"        -- isAdministrator(), getInterfaceId()
require "label_utils"       -- getHumanReadableInterfaceName()
require "check_redis_prefs" -- interfaceHasClickHouseSupport()
require "lua_utils_get"     -- getPasswordInputPattern()
local rest_utils    = require "rest_utils"
local locales_utils = require "locales_utils"

--
-- The ntopng users (Admin > Users page) and the options of the user forms.
-- Administrators get all the users (captive portal users excluded, they are
-- managed by the nEdge pages), the other users only their own profile.
-- (Not get/ntopng/users.lua: that public endpoint returns ntop.getUsers() as is)
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/users_list.lua
--

local is_admin = isAdministrator()
local logged_user = _SESSION and _SESSION["user"] or ""
local all_users = ntop.getUsers() or {}

local users = {}

for username, user in pairs(all_users) do
   if (user["group"] ~= "captive_portal") and (is_admin or username == logged_user) then
      users[#users + 1] = {
         username = username,
         full_name = user["full_name"] or "",
         group = user["group"] or "",
         totp_enabled = ntop.isTOTPEnabled(username) and true or false,
         is_self = (username == logged_user),
         -- The built-in admin and the logged user cannot be deleted (also
         -- enforced by rest/v2/delete/ntopng/user.lua)
         can_delete = is_admin and (username ~= "admin") and (username ~= logged_user),
      }
   end
end

table.sort(users, function(a, b) return a.username < b.username end)

-- Options of the add/edit forms
local options = {
   is_admin = is_admin,
   logged_user = logged_user,
   password_pattern = getPasswordInputPattern(),
   -- Passkeys can be configured only over HTTPS (see the login)
   is_https = ntop.isHTTPS() and true or false,
   clickhouse_enabled = interfaceHasClickHouseSupport() and true or false,
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) and true or false,
   locales = {},
}

for _, lang in ipairs(locales_utils.getAvailableLocales()) do
   options.locales[#options.locales + 1] = { code = lang["code"], label = i18n("locales." .. lang["code"]) }
end

-- Interfaces and host pools: only administrators can assign them
if is_admin then
   local host_pools = require "host_pools"

   options.interfaces = {}
   for _, ifname in pairs(interface.getIfNames()) do
      options.interfaces[#options.interfaces + 1] = {
         id = tostring(getInterfaceId(ifname)),
         label = getHumanReadableInterfaceName(ifname),
      }
   end
   table.sort(options.interfaces, function(a, b) return a.label < b.label end)

   options.host_pools = {}
   for _, pool in ipairs(host_pools:create():get_all_pools()) do
      options.host_pools[#options.host_pools + 1] = { id = tostring(pool["pool_id"]), name = pool["name"] }
   end
end

rest_utils.answer(rest_utils.consts.success.ok, { users = users, options = options })
