--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?/init.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"
require "graph_utils"
local json = require("dkjson")
local i18n = require "i18n"

local locale = _GET["locale"]
if locale == nil or locale:len() ~= 2 or not string.match(locale, "^%a%a$") then
   locale = "en"
end

i18n.loadFile(dirs.installdir..'/scripts/locales/'..locale..'.lua') -- maybe load some more stuff from that file

-- setting the translation context
i18n.setLocale(locale)

-- getting translations
local res = {localized_msg_1 = i18n('welcome'),
	     localized_msg_2 = i18n('version', {vers = ntop.getInfo()["version"]}),
	     localized_msg_3 = i18n('report.period'),
	     localized_msg_4 = i18n('report.date', {year=2016-18, day=10, month=11})}

-- must use utf8 if you want to print special chars
sendHTTPHeader('text/json; charset=utf-8')
print(json.encode({locale = locale, res = res}, nil))
