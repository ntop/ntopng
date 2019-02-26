--
-- (C) 2017-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local json = require("dkjson")
local dhcp_utils = require("dhcp_utils")
require "lua_utils"

sendHTTPContentTypeHeader('text/json')

local ifid = _GET["ifid"]
local rv = {data={}, sort={{"column_", "asc"}}, totalRows=0}
local res = rv.data

if((ifid ~= nil) and (isAdministrator())) then
  interface.select(getInterfaceName(ifid))

  for _, range in ipairs(dhcp_utils.listRanges(ifid)) do
    res[#res + 1] = {
      column_first_ip = range[1],
      column_last_ip = range[2],
    }

    rv.totalRows = rv.totalRows + 1
  end
end

print(json.encode(rv))
