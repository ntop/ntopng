--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if ntop.isPro() then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
end

require "lua_utils"
local json = require("dkjson")
local flow_dbms = require("flow_dbms"):new()

local ifid = getInterfaceId(ifname)

local now = os.time()
local ago_1h = now - 3600

local filter = {epoch_begin = ago_1h, epoch_end = now, offset = 0, limit = 10}

sendHTTPHeader('application/json')

local topk_host = flow_dbms:queryTopk(ifid, "host", filter)
local topk_port = flow_dbms:queryTopk(ifid, "port", filter)

local res = {topk_host = topk_host, topk_port = topk_port}

print(json.encode(res))
