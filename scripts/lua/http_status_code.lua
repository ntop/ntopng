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

message = "http_status_code."..message

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[
    <div style="height: 80vh" class='row my-4'>
        <div class='col pl-5 d-flex justify-content-center flex-column align-items-center'>
            <h2 class='mb-5' style='font-size: 4rem'>
                <b>Whops!</b>
                <br>
                ]].. i18n("error_page.presence").. [[!
            </h2>
            <p class="lead mt-1 mb-5 text-danger">
                ]].. i18n("error_page.greeting").. [[: <br>
                <b>]].. error_message ..[[</b>
                <small>(]].. message ..[[)</small>
            </p>
            <a class='btn-primary btn mb-5' href="]]..referal_url..[[">
                <i class="fas fa-arrow-left"></i> ]].. i18n("error_page.go_back").. [[
            </a>
        </div>
        <div class='col p-2 text-center d-flex justify-content-center align-items-center'>
            <i class="fas fa-exclamation-triangle bigger-icon"></i>
        </div>
    </div>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
