--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local graph_utils = require "graph_utils"

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local ifstats = interface.getFlowsStatus()
local res = {
   { 
      label = i18n('enstablished'),
      value = ifstats["Established"],
   },
   { 
      label = i18n('syn'),
      value = ifstats["SYN"],
   },
   { 
      label = i18n('rst'),
      value = ifstats["RST"],
   },
   { 
      label = i18n('fin'),
      value = ifstats["FIN"],
   },
}

rest_utils.answer(rc, graph_utils.convert_pie_data(res, true, "formatValue"))