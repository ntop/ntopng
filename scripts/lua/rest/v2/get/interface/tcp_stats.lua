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

local function add_entry(t, label_key, val)
  if val ~= 0 then
    table.insert(t, { label = i18n(label_key), value = val })
  end
end

local data = {}
add_entry(data, 'enstablished', ifstats["Established"])
add_entry(data, 'syn',          ifstats["SYN"])
add_entry(data, 'rst',          ifstats["RST"])
add_entry(data, 'fin',          ifstats["FIN"])

rest_utils.answer(rest_utils.consts.success.ok, data)