--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local format_utils = require("format_utils")

local plugins_utils = require "plugins_utils"
local notification_endpoints = require("notification_endpoints")
local notification_recipients = require("notification_recipients")

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

res = notification_endpoints.reset_configs()
assert(res["status"] == "OK")

res = notification_endpoints.delete_config("nonexisting_config_name")
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_config_not_existing")

res = notification_endpoints.add_config("nonexisting", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_not_existing")

res = notification_endpoints.add_config("email", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "invalid_endpoint_conf_name")

res = notification_endpoints.add_config("email", "ntop_email", nil)

assert(res["status"] == "failed" and res["error"]["type"] == "invalid_conf_params")

-- see email.lua for mandatory conf_params
local conf_params = {
   smtp_server_name = "mail.ntop.org"
}

res = notification_endpoints.add_config("email", "ntop_email", conf_params)
assert(res["status"] == "failed" and res["error"]["type"] == "missing_mandatory_param")

conf_params = {
   smtp_server_name = "mail.ntop.org",
   sender = "tester@ntop.org"
}
res = notification_endpoints.add_config("email", "ntop_email", conf_params)
assert(res["status"] == "OK")

-- Duplicate addition
res = notification_endpoints.add_config("email", "ntop_email", conf_params)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_config_already_existing")

-- Delete the endpoint
res = notification_endpoints.delete_config("ntop_email")
assert(res["status"] == "OK")

-- Add also some optional params
conf_params = {
   smtp_server_name = "mail.ntop.org",
   sender = "tester@ntop.org",
   username = "ntopuser",
   password = "ntoppassword"
}

res = notification_endpoints.add_config("email", "ntop_email", conf_params)
assert(res["status"] == "OK")

res = notification_endpoints.delete_config("ntop_email")
assert(res["status"] == "OK")

-- Add some garbage and make sure it is not written
conf_params["garbage"] = "trash"

res = notification_endpoints.add_config("email", "ntop_email", conf_params)
assert(res["status"] == "OK")

res = notification_endpoints.get_endpoint_config("ntop_email")
assert(res["status"] == "OK")
assert(res["endpoint_key"] == "email")
assert(res["endpoint_conf_name"] == "ntop_email")
assert(res["endpoint_conf"])
assert(not res["endpoint_conf"]["garbage"])

for k, v in pairs(res["endpoint_conf"]) do
   assert(conf_params[k])
   assert(conf_params[k] == v)
end

-- Edit the config
conf_params["smtp_server_name"] = "mail2.ntop.org"
res = notification_endpoints.edit_config("ntop_email", conf_params)
assert(res["status"] == "OK")

res = notification_endpoints.get_endpoint_config("ntop_email")
assert(res["status"] == "OK")
assert(res["endpoint_key"] == "email")
assert(res["endpoint_conf_name"] == "ntop_email")
assert(res["endpoint_conf"])
assert(res["endpoint_conf"]["smtp_server_name"] == "mail2.ntop.org")

-- Add another endpoint
conf_params = {
   smtp_server_name = "mail.google.com",
   sender = "tester@google.com",
   username = "googleuser",
   password = "googlepassword"
}

res = notification_endpoints.add_config("email", "google_email", conf_params)
assert(res["status"] == "OK")

-- Get all configs
res = notification_endpoints.get_configs()
assert(#res == 2)

------------------------------
-- TEST ENDPOINT RECIPIENTS --
------------------------------

-- Test the addition
res = notification_recipients.add_recipient("nonexisting_config_name", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_config_not_existing")

res = notification_recipients.add_recipient("ntop_email", nil, nil)
assert(res["status"] == "failed" and res["error"]["type"] == "invalid_endpoint_recipient_name")

res = notification_recipients.add_recipient("ntop_email", "sysadmins", nil)
assert(res["status"] == "failed" and res["error"]["type"] == "invalid_recipient_params")

res = notification_recipients.add_recipient("ntop_email", "sysadmins", {})
assert(res["status"] == "failed" and res["error"]["type"] == "missing_mandatory_param")

local recipient_params = {
   to = "ci@ntop.org"
}

res = notification_recipients.add_recipient("ntop_email", "sysadmins", recipient_params)
assert(res["status"] == "OK")

-- See if duplicate recipient is detected
res = notification_recipients.add_recipient("ntop_email", "sysadmins", recipient_params)
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_recipient_already_existing")

-- Test deletion
res = notification_recipients.delete_recipient("sysadmins")
assert(res["status"] == "OK")

res = notification_recipients.delete_recipient("sysadmins")
assert(res["status"] == "failed" and res["error"]["type"] == "endpoint_recipient_not_existing")

recipient_params["garbage"] = "trash"

res = notification_recipients.add_recipient("ntop_email", "sysadmins", recipient_params)
assert(res["status"] == "OK")

res = notification_recipients.get_recipient("sysadmins")
assert(res["status"] == "OK")
assert(res["recipient_params"])
assert(res["recipient_params"]["to"] == "ci@ntop.org")
assert(not res["recipient_params"]["garbage"])

-- Test edit
recipient_params["to"] = "ci2@ntop.org"
res = notification_recipients.edit_recipient("sysadmins", recipient_params)
assert(res["status"] == "OK")

res = notification_recipients.get_recipient("sysadmins")
assert(res["status"] == "OK")
assert(res["recipient_params"])
assert(res["recipient_params"]["to"] == "ci2@ntop.org")

-- Add another couple of recipients
recipient_params["to"] = "devops2@ntop.org"
res = notification_recipients.add_recipient("ntop_email", "devops", recipient_params)
assert(res["status"] == "OK")

recipient_params["to"] = "sres@gmail.com"
res = notification_recipients.add_recipient("google_email", "sres", recipient_params)
assert(res["status"] == "OK")

res = notification_recipients.get_recipients()
assert(#res == 3)
for _, recipient in pairs(res) do
   assert(recipient["status"] == "OK")
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

