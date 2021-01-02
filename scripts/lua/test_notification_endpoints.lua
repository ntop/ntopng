--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/notifications/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local format_utils = require("format_utils")

local plugins_utils = require "plugins_utils"
local endpoints = require("endpoints")
local recipients_module = require("recipients")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))

if not isAdministrator() then
  return
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local res

---------------------------
-- TEST ENDPOINT CONFIGS --
---------------------------

res = endpoints.reset_configs()
assert(res["status"] == "OK")

res = endpoints.delete_config("nonexisting_config_name")
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_config_not_existing")

res = endpoints.add_config("nonexisting", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_not_existing")

res = endpoints.add_config("email", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "invalid_endpoint_conf_name")

res = endpoints.add_config("email", "ntop_email", nil)

assert(res["status"] == "failed" and res["error"]["type"] == "invalid_endpoint_params")

-- see email.lua for mandatory endpoint_params
local endpoint_params = {
   smtp_server = "mail.ntop.org"
}

res = endpoints.add_config("email", "ntop_email", endpoint_params)
assert(res["status"] == "failed" and res["error"]["type"] == "missing_mandatory_param")

endpoint_params = {
   smtp_server = "mail.ntop.org",
   email_sender = "tester@ntop.org"
}
res = endpoints.add_config("email", "ntop_email", endpoint_params)
assert(res["status"] == "OK")

-- Duplicate addition
res = endpoints.add_config("email", "ntop_email", endpoint_params)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_config_already_existing")

-- Delete the endpoint
res = endpoints.delete_config("ntop_email")
tprint(res)
assert(res["status"] == "OK")

-- Add also some optional params
endpoint_params = {
   smtp_server = "mail.ntop.org",
   email_sender = "tester@ntop.org",
   smpt_username = "ntopuser",
   smtp_password = "ntoppassword"
}

res = endpoints.add_config("email", "ntop_email", endpoint_params)
assert(res["status"] == "OK")

res = endpoints.delete_config("ntop_email")
assert(res["status"] == "OK")

-- Add some garbage and make sure it is not written
endpoint_params["garbage"] = "trash"

res = endpoints.add_config("email", "ntop_email", endpoint_params)
assert(res["status"] == "OK")

res = endpoints.get_endpoint_config("ntop_email")
assert(res["status"] == "OK")
assert(res["endpoint_key"] == "email")
assert(res["endpoint_conf_name"] == "ntop_email")
assert(res["endpoint_conf"])
assert(not res["endpoint_conf"]["garbage"])

for k, v in pairs(res["endpoint_conf"]) do
   assert(endpoint_params[k])
   assert(endpoint_params[k] == v)
end

-- Edit the config
endpoint_params["smtp_server"] = "mail2.ntop.org"
res = endpoints.edit_config("ntop_email", endpoint_params)
assert(res["status"] == "OK")

res = endpoints.get_endpoint_config("ntop_email")
assert(res["status"] == "OK")
assert(res["endpoint_key"] == "email")
assert(res["endpoint_conf_name"] == "ntop_email")
assert(res["endpoint_conf"])
assert(res["endpoint_conf"]["smtp_server"] == "mail2.ntop.org")

-- Add another endpoint
endpoint_params = {
   smtp_server = "mail.google.com",
   email_sender = "tester@google.com",
   smpt_username = "googleuser",
   smtp_password = "googlepassword"
}

res = endpoints.add_config("email", "google_email", endpoint_params)
assert(res["status"] == "OK")

-- Get all configs
res = endpoints.get_configs()
assert(#res == 2)

------------------------------
-- TEST ENDPOINT RECIPIENTS --
------------------------------

-- Test the addition
res = recipients_module.add_recipient("nonexisting_config_name", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_config_not_existing")

res = recipients_module.add_recipient("ntop_email", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "invalid_endpoint_recipient_name")

res = recipients_module.add_recipient("ntop_email", "sysadmins", nil)
assert(res["status"] == "failed" and res["error"]["type"] == "invalid_recipient_params")

res = recipients_module.add_recipient("ntop_email", "sysadmins", {})
assert(res["status"] == "failed" and res["error"]["type"] == "missing_mandatory_param")

local recipient_params = {
   email_recipient = "ci@ntop.org"
}

res = recipients_module.add_recipient("ntop_email", "sysadmins", recipient_params)
assert(res["status"] == "OK")

-- See if duplicate recipient is detected
res = recipients_module.add_recipient("ntop_email", "sysadmins", recipient_params)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_recipient_already_existing")

-- Test deletion
res = recipients_module.delete_recipient("sysadmins")
assert(res["status"] == "OK")

res = recipients_module.delete_recipient("sysadmins")
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_recipient_not_existing")

recipient_params["garbage"] = "trash"

res = recipients_module.add_recipient("ntop_email", "sysadmins", recipient_params)
assert(res["status"] == "OK")

res = recipients_module.get_recipient("sysadmins")
assert(res["status"] == "OK")
assert(res["recipient_params"])
assert(res["recipient_params"]["email_recipient"] == "ci@ntop.org")
assert(not res["recipient_params"]["garbage"])

-- Test edit
recipient_params["email_recipient"] = "ci2@ntop.org"
res = recipients_module.edit_recipient("sysadmins", recipient_params)
assert(res["status"] == "OK")

res = recipients_module.get_recipient("sysadmins")
assert(res["status"] == "OK")
assert(res["recipient_params"])
assert(res["recipient_params"]["email_recipient"] == "ci2@ntop.org")

-- Add another couple of recipients
recipient_params["email_recipient"] = "devops2@ntop.org"
res = recipients_module.add_recipient("ntop_email", "devops", recipient_params)
assert(res["status"] == "OK")

recipient_params["email_recipient"] = "sres@gmail.com"
res = recipients_module.add_recipient("google_email", "sres", recipient_params)
assert(res["status"] == "OK")

res = recipients_module.get_recipients()

assert(#res == 3)
for _, recipient in pairs(res) do
   assert(recipient["status"] == "OK")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

