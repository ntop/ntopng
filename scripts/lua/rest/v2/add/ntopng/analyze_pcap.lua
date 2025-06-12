--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local template = require "template_utils"
local rest_utils = require "rest_utils"

local current_ifid = interface.getId()
local ifid = _POST["ifid"] or interface.getId()
local create_new_iface = _POST["create_new_interface"]
local uploaded_file = _POST["uploaded_file"]
local rc = rest_utils.consts.success.ok
local rsp = {}
local error_msg = nil

if ifid then
   interface.select(ifid)
end

if not uploaded_file then
   rc = rest_utils.consts.err.invalid_args
   rest_utils.answer(rc)
end

if(create_new_iface == "true") then
   create_new_iface = true
else
   create_new_iface = false
end

if(uploaded_file ~= nil) then
   local iface_id = ntop.registerRuntimeInterface('pcap:' .. uploaded_file, -- pcap path
     uploaded_file, -- interface name
     create_new_iface) -- create new or reuse
   if iface_id and iface_id > 0 then
      rsp = {
         new_ifid = iface_id
      }
   else
      rc = rest_utils.consts.err.internal_error
      error_msg = i18n("analyze_pcap_error")
      ntop.unlink(uploaded_file)
   end
end

if tonumber(current_ifid) ~= tonumber(ifid) then
   interface.select(current_ifid)
end

rest_utils.answer(rc, rsp, nil, error_msg)
