--
-- (C) 2020 - ntop.org
--

-- This page shows the HTTP errors that a user can get
-- example: 404, 403, ...

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')
page_utils.print_header()

local message        = _GET["message"] or "forbidden"
local referal_url    = _GET["referer"] or '/'
local error_message  = _GET["error_message"] or ""

referal_url = string.sub(referal_url, string.find(referal_url, "/"))
message = "http_status_code."..message

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[
    <div style="height: 80vh" class='row my-4'>
        <div class='col pl-5 d-flex justify-content-left flex-column align-items-left'>
            <h2 class='mb-5 w-100' style='font-size: 4rem'>
                <b>]].. i18n("error_page.presence").. [[</b>
            </h2>
            <b>]])

print(i18n(message))

   print('</b></p><p class="text-danger">'..error_message)
print([[</p>

            <a class='btn-primary btn mb-3' href="]]..referal_url..[[">
               ]].. i18n("error_page.go_back").. [[
            </a>
        </div>
        <div class='col p-2 text-left d-flex justify-content-left align-items-left'>
            <i class="fas fa-exclamation-triangle bigger-icon"></i>
        </div>
    </div>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
