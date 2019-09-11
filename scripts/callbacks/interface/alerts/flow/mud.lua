--
-- (C) 2019 - ntop.org
--

local mud_utils = require "mud_utils"

local flow_module = {}

-- #################################################################

function flow_module.setup()
  return(mud_utils.isMUDRecordingEnabled(interface.getId()))
end

-- #################################################################

function flow_module.protocolDetected(info)
  mud_utils.handleFlow(info)
end

-- #################################################################

return(flow_module)
