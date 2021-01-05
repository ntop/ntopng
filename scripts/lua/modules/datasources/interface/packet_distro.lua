--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datasources/?.lua;" .. package.path

-- ##############################################

-- Import the classes library.
local classes = require "classes"
-- Import the base class
local datasource = require "datasource"
-- This is the datamodel used to represent data associated with this datasource
local datamodel = require "datamodel_utils"
-- Rest utilities
local rest_utils = require "rest_utils"

-- ##############################################

local packet_distro = classes.class(datasource)

-- ##############################################

packet_distro.meta = {
   i18n_title = "Interface Packet Distribution",
   icon = "fas fa-exclamation",
   rest_endpoint = "/lua/rest/v1/datasources/interface/packet_distro.lua",
   datamodel = datamodel,
}

-- ##############################################

-- @brief Datasource constructor
function packet_distro:init()
   -- Call the paren constructor
   self.super:init()
end

-- #######################################################

function packet_distro.rest_response()
   -- TODO: parse get params
  local m = packet_distro.meta.datamodel:create("packet distro")
  local when = os.time()
  local dataset = getInterfaceName(interface.getId()).. " Packet Distribution"

  m:appendRow(when, dataset, {1, 2})
  m:appendRow(when, dataset, {3, 4})

  rest_utils.answer(
     rest_utils.consts.success.ok,
     m:getAsTable() -- TODO: this should be a generic response, not Table
  )
end

-- #######################################################

return packet_distro
