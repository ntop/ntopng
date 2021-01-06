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
-- Import the datasource keys
local datasource_keys = require "datasource_keys"
-- This is the datamodel used to represent data associated with this datasource
local datamodel = require "datamodel"
-- Rest utilities
local rest_utils = require "rest_utils"

-- ##############################################

local packet_distro = classes.class(datasource)

-- ##############################################

packet_distro.meta = {
   datasource_key = datasource_keys.interface_packet_distro, -- Uniquely identifies this datasource
   i18n_title = "Interface Packet Distribution",
   icon = "fas fa-exclamation",
   rest_endpoint = "/lua/rest/v1/get/datasource/interface/packet_distro.lua",
   datamodel = datamodel,
   params = {
      "ifid" -- validated according to http_lint.lua
   },
}

-- ##############################################

-- Human-friendly labels for the distribution
packet_distro.labels = {
   ['upTo64']    = '<= 64',
   ['upTo128']   = '64 <= 128',
   ['upTo256']   = '128 <= 256',
   ['upTo512']   = '256 <= 512',
   ['upTo1024']  = '512 <= 1024',
   ['upTo1518']  = '1024 <= 1518',
   ['upTo2500']  = '1518 <= 2500',
   ['upTo6500']  = '2500 <= 6500',
   ['upTo9000']  = '6500 <= 9000',
   ['above9000'] = '> 9000'
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
   local ifstats = interface.getStats()
   local size_bins = ifstats["pktSizeDistribution"]["size"]

   self.datamodel_instance = self.meta.datamodel:new(self.meta.i18n_title)

   for bin, num_packets in pairs(size_bins) do
      self.datamodel_instance:append(packet_distro.labels[bin], num_packets)
   end
end

-- #######################################################

return packet_distro
