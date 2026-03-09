--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local graph_utils = require "graph_utils"

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
  rest_utils.answer(rest_utils.consts.err.invalid_interface)
  return
end

interface.select(ifid)

local ifstats = interface.getFlowsStatus()

local data = {
  { label = i18n('enstablished'), value = ifstats["Established"] },
  { label = i18n('syn'),          value = ifstats["SYN"]         },
  { label = i18n('rst'),          value = ifstats["RST"]         },
  { label = i18n('fin'),          value = ifstats["FIN"]         },
}

rest_utils.answer(rest_utils.consts.success.ok, data)