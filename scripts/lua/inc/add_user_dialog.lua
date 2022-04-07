--
-- (C) 2022 - ntop.org
--

require "lua_utils"
local locales_utils = require "locales_utils"
local template_utils = require "template_utils"
local recording_utils = require "recording_utils"

local messages = {
  ntopng = ternary(ntop.isnEdge(), i18n("nedge.add_system_user"), i18n("login.add_web_user")),
  username = i18n("login.username"),
  full_name = i18n("users.full_name"),
  password = i18n("login.password"),
  confirm_password = i18n("login.confirm_password"),
  user_role = i18n("manage_users.user_role"),
  non_privileged_user = i18n("manage_users.non_privileged_user"),
  administrator = i18n("manage_users.administrator"),
  allowed_interface = i18n("manage_users.allowed_interface"),
  any_interface = i18n("manage_users.any_interface"),
  allowed_networks = i18n("manage_users.allowed_networks"),
  allowed_networks_descr = i18n("manage_users.allowed_networks_descr") .. " 192.168.1.0/24,172.16.0.0/16",
  language = i18n("language"),
  add_new_user = i18n("manage_users.add_new_user"),
  allow_historical_flow = i18n("manage_users.allow_historical_flow"),
  allow_historical_flow_descr = i18n("manage_users.allow_historical_flow_descr"),
  allow_pcap_download = i18n("manage_users.allow_pcap_download"),
  allow_pcap_download_descr = i18n("manage_users.allow_pcap_download_descr"),
}

local interfaces_names = {}

for _, interface in pairs(interface.getIfNames()) do
  interfaces_names["interface"] = {
    label = getHumanReadableInterfaceName(interface),
    id = getInterfaceId(interface)
  }
end

local add_user_msg = messages["ntopng"]
local http_prefix = ntop.getHttpPrefix()
local csrf = ntop.getRandomCSRFValue()
local available_locales = {}

for _, lang in pairs(locales_utils.getAvailableLocales()) do
  available_locales[#available_locales + 1] = {
    code = lang["code"],
    label = i18n("locales." .. lang["code"]),
  }
end

local add_user = http_prefix .. '/lua/rest/v2/add/ntopng/user.lua'
local clickhouse_enabled = interfaceHasClickHouseSupport()
local location_href = ntop.getHttpPrefix().."/lua/admin/users.lua"
local is_pcap_download_available = true or recording_utils.isAvailable()

template_utils.render("pages/components/add-user-dialog.template", {
  add_user_endpoint = add_user,
  available_locales = available_locales,
  csrf = csrf,
  add_user_msg = add_user_msg,
  http_prefix = http_prefix,
  interfaces_names = interfaces_names,
  messages = messages,
  template_utils = template_utils,
  location_href = location_href,
  clickhouse_enabled = clickhouse_enabled,
  is_pcap_download_available = is_pcap_download_available
})



