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

local status_code = _GET["status_code"] or 200
local referal_url = _GET["referal_url"] or '/'

local error_descriptions = {
    [404] = "Page not found!",
    [403] = "Forbidden page!",
    [200] = "Success!",
}

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[
    <div class='row mb-4'>
        <div class='col'>
            <i class="fas fa-exclamation-triangle"></i>
            <h2 class='text-center status-code-title mt-3 mb-1'>]].. status_code ..[[</h2>
            <h3 class='text-center mt-1 mb-3 text-muted'>Ops! Something went wrong!</h3>
            <p class='text-center mt-3 mb-4 lead'>
                ]].. error_descriptions[status_code] ..[[
            </p>
            <a class='text-center d-block mb-5' href="]]..referal_url..[[">
                <i class="fas fa-arrow-left"></i>
                Bring me back
            </a>
        </div>
    </div>
]])

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
