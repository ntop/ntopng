--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require ("dkjson")
local tracker = require("tracker")
local rest_utils = require("rest_utils")

--
-- Read information about a host
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "mac" : "FF:FF:FF:FF:FF:FF"}' http://localhost:3000/lua/rest/v2/get/mac/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local mac = _GET["mac"]

local function format_data(mac) 
    local res = {}
    if not isEmptyString(mac["fingerprint"]) then
        res["fingerprint"] = mac["fingerprint"]
    end
    
    res["first_seen"] = mac["seen.first"]
    res["last_seen"] = mac["seen.last"]
    res["num_hosts"] = mac["num_hosts"]
    res["tot_bytes_sent"] = mac["bytes.sent"]
    res["tot_bytes_recv"] = mac["bytes.recv"]
    
    res["arp"] = {}
    res["arp"]["arp_replies.rcvd"]=mac["arp_replies.rcvd"]
    res["arp"]["arp_replies_sent"]=mac["arp_replies.sent"]
    res["arp"]["arp_requests_rcvd"]=mac["arp_requests.rcvd"]
    res["arp"]["arp_requests_sent"]=mac["arp_requests.sent"]
    return res 
end

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

interface.select(ifid)

if not mac then
    local macs = interface.getMacsInfo(nil, nil, nil, nil,true --[[ sourceMacsOnly ]], nil, nil, nil, nil, nil)
    for k, v in pairs(macs["macs"]) do
        res[v["mac"]] = format_data(v)
    end
else
    local mac = interface.getMacInfo(mac)
    if not mac then
        rest_utils.answer(rest_utils.consts.err.not_found)
        return
    end

    res = format_data(mac)
end

rest_utils.answer(rc, res)

