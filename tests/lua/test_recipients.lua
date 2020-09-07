--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end
require "lua_utils"

package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path
local json = require "dkjson"
local recipients = require "recipients"
local r = recipients:create()

r:cleanup()

local res1 = r:add_recipient("ntop_mail", "ntop_mail_r", {email_recipient = "test@ntop.org"})
assert(res1.status == "OK")
local res2 = r:add_recipient("ntop_mail", "ntop_mail_r", {email_recipient = "test2@ntop.org"})
assert(res2.status == "failed")
local res3 = r:add_recipient("ntop_mail", "ntop_mail_r3", {email_recipient = "test3@ntop.org"})
assert(res2.status == "failed")
local r1 = r:get_recipient(1)
local r2 = r:get_recipient(2)

local e1 = r:edit_recipient(res1.recipient_id, "ntop_mail_r_edited", {email_recipient = "test4@ntop.org"})

local res = r:test_recipient("ntop_mail", {email_recipient = "test4@ntop.org", cc = ""})
-- tprint(res)
--tprint(e1)
-- tprint(r:get_recipient(res1.recipient_id))
-- tprint(res2)
-- tprint(r1)
-- tprint(r2)
--tprint(r:get_recipient_by_name("mainardi_mail"))

-- tprint(r:get_all_recipients())

print("OK\n")
