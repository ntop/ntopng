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
   rest_endpoint = "/lua/rest/v1/get/datasource/interface/packet_distro.lua",
   datamodel = datamodel,
   params = {
      "ifid" -- validated according to http_lint.lua
   },
}

-- ##############################################

-- @brief Datasource constructor
function packet_distro:init()
   -- Call the paren constructor
   self.super:init()
end

-- #######################################################

function packet_distro:fetch()
   -- Assumes all parameters listed in self.meta.params have been parsed successfully
   -- and are available in self.parsed_params

   interface.select(tostring(self.parsed_params.ifid))

   self.datamodel_instance = self.meta.datamodel:create("packet distro")
   local when = os.time()
   local dataset = getInterfaceName(interface.getId()).. " Packet Distribution"

   self.datamodel_instance:appendRow(when, dataset, {1, 2})
   self.datamodel_instance:appendRow(when, dataset, {3, 4})
end

-- #######################################################

return packet_distro
