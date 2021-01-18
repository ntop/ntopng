--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datamodel/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/rest/v1/get/datasource/?.lua;" .. package.path

-- ##############################################

-- Import the classes library.
local classes = require "classes"
-- Import the base class
local datasource = require "datasource"
-- Import the datasource keys
local datasource_keys = require "datasource_keys"
-- This is the datamodel used to represent data associated with this datasource
local datamodel = require "slices"
-- Rest utilities
local rest_utils = require "rest_utils"

-- ##############################################

local packet_distro = classes.class(datasource)

-- ##############################################

packet_distro.meta = {
   datasource_key = datasource_keys.interface_packet_distro, -- Uniquely identifies this datasource
   i18n_title = "Interface Packet Distribution",
   icon = "fas fa-exclamation",
   datamodel = datamodel,
   params = {
      "ifid" -- validated according to http_lint.lua
   },
   -- A URL possibly formatted with parsed_params sent via REST
   url = "/lua/if_stats.lua?ifid={{ params.ifid }}&page=packets",
   -- Possibly add placeholders to replace keys and values, e.g., 
   -- k is the `k` in the response data, v is the `v` in the response data
   -- url = "/lua/if_stats.lua?ifid={{ params.ifid }}&page=packets&key=__k__&value=__v__",
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
   -- Call the parent constructor
   self.super:init()

   self.datasource_key_str = datasource_keys[datasource.ds_type]
end

-- #######################################################

function packet_distro:fetch()
   -- Assumes all parameters listed in self.meta.params have been parsed successfully
   -- and are available in self.parsed_params

   interface.select(tostring(self.parsed_params.ifid))
   local ifstats = interface.getStats()
   local size_bins = ifstats["pktSizeDistribution"]["size"]

   self.datamodel_instance = self.meta.datamodel.new(
      self.meta.i18n_title,
      10 --[[ Maximum number of slices ]],
      3 --[[ Percentage under which the slice is ignored and added to other --]])

   for bin, num_packets in pairsByKeys(size_bins) do
      self.datamodel_instance:append(packet_distro.labels[bin], num_packets)
   end

   -- Consolidate `append`ed data
   self.datamodel_instance:consolidate()
end

-- #######################################################

-- Checks if this module is being loaded as part of a REST request to this endpoint or not.
-- If the module is being loaded as part of a REST request, then a response is sent, otherwise nothing is done.
-- Must call this to ensure REST responses are sent when necessary
packet_distro:new():rest_send_response()

-- #######################################################

return packet_distro
