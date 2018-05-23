--
-- (C) 2013-18 - ntop.org
--

--
-- JSON POST example
--
-- curl -X POST -H "Content-Type: application/json" -d @req.json http://localhost:3000/lua/jsontest.lua
--
-- Put in req.json a valid JSON
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
json = require("dkjson")

sendHTTPContentTypeHeader('text/html')

-- print(_POST["JSON"])

local info, pos, err = json.decode(_POST["JSON"], 1, nil)

print(info.responseId.."\n")


rsp = {}
rsp.info = "sdasdasdas"
rsp.req = {}
rsp.req.luca = "deri"

local js = json.encode(rsp)

print(js.."\n")

   
