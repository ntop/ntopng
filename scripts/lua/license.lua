--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require "template_utils"
local json = require "dkjson"
local format_utils = require("format_utils")

if not isAdministratorOrPrintErr() then return end

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.license)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
page_utils.print_page_title(i18n("license_page.license"))

if(_POST["ntopng_license"] ~= nil) then
    ntop.setCache('ntopng.license', trimSpace(_POST["ntopng_license"]))
    ntop.checkLicense()
end

local info = ntop.getInfo()
info["ntopng.license"] = ntop.getCache('ntopng.license')

local external_link = ternary(info["pro.release"], "https://www.ntop.org/support/faq/what-is-the-end-user-license-agreement-for-binary-products/", "http://www.gnu.org/licenses/gpl.html")
local version = split(info["version"], " ")
local edition

if(ntop.isnEdge()) then
    if(info["version.nedge_enterprise_edition"] == true) then
        if(info["version.embedded_edition"] == true) then
           edition = ("nedge_embedded_ent")
        else
            edition = ("nedge_enterprise")
        end
    else
        if(info["version.embedded_edition"] == true) then
            edition = ("nedge_embedded_pro")
        else
            edition = ("nedge_pro")
        end
    end
 else
    if(info["version.embedded_edition"] == true) then
        edition = ("embedded")
    elseif(info["version.enterprise_edition"] == true) then
        edition = ("enterprise")
    else
        edition = ("pro")
    end
 end

local systemIdHref = string.format("https://shop.ntop.org/mkntopng?systemid=%s&version=%s&edition=%s", info["pro.systemid"], version[1], edition)
local context = {
    info = info,
    format_utils = format_utils,
    ui_utils = ui_utils,
    license = {
        external_link = external_link,
        version = version,
        systemIdHref = systemIdHref,
        is_admin = isAdministrator()
    }
}

-- print .html template
if info["pro.systemid"] and (info["pro.systemid"] ~= "") then
    print(template.gen("pages/license.template", context))
end

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
