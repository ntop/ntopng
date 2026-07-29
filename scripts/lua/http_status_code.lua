--
-- (C) 2026 - ntop.org
--

-- This page shows the HTTP errors that a user can get
-- example: 404, 403, ...

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local page_utils     = require("page_utils")
local json           = require "dkjson"
local template_utils = require "template_utils"

local message       = _GET["message"] or "forbidden"
local referal_url   = _GET["referer"] or '/'
local error_message = _GET["error_message"] or ""

local status_code
if(message == "not_found") then
   status_code = 404
elseif(message == "internal_error") then
   status_code = 500
else
   status_code = 403 -- forbidden
end

sendHTTPContentTypeHeader('text/html', nil, nil, nil, status_code)
page_utils.print_header()

referal_url = string.sub(referal_url, string.find(referal_url, "/"), string.len(referal_url))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
  message_key  = "http_status_code."..message,
  error_message = error_message,
  referal_url   = referal_url,
}

template_utils.render("pages/vue_page.template", {
  vue_page_name = "PageHttpStatusCode",
  page_context  = json.encode(context)
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
