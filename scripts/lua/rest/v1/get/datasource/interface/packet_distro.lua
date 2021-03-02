--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datamodel/?.lua;" .. package.path

-- ##############################################

-- Import the classes library.
local classes = require "classes"
-- This is the datamodel used to represent data associated with this datasource
local slices = require "slices"
-- Rest utilities
local rest_utils = require "rest_utils"

-- ##############################################

local packet_distro = classes.class(slices)

-- ##############################################

packet_distro.meta = {
   params = {
      -- NOTE: Specify all the parameter keys that must be passed in the request
       "ifid" -- validated according to http_lint.lua
   },
}

-- ##############################################

-- Human-friendly labels for the distribution
local available_bins = {
   { key = 'upTo64',    label = '<= 64'        },
   { key = 'upTo128',   label = '64 <= 128'    },
   { key = 'upTo256',   label = '128 <= 256'   },
   { key = 'upTo512',   label = '256 <= 512'   },
   { key = 'upTo1024',  label = '512 <= 1024'  },
   { key = 'upTo1518',  label = '1024 <= 1518' },
   { key = 'upTo2500',  label = '1518 <= 2500' },
   { key = 'upTo6500',  label = '2500 <= 6500' },
   { key = 'upTo9000',  label = '6500 <= 9000' },
   { key = 'above9000', label = '> 9000'       },
}

-- ##############################################

-- @brief Datasource constructor
function packet_distro:init()
   -- Initializes parent class slices
   self.super:init(10 --[[ Maximum number of slices ]],
		   3 --[[ Percentage under which the slice is ignored and added to other --]])
end

-- #######################################################

function packet_distro:fetch()
   -- Assumes all parameters listed in self.meta.params have been parsed successfully
   -- and are available in self.parsed_params

   interface.select(tostring(self.parsed_params.ifid))
   local ifstats = interface.getStats()
   local size_bins = ifstats["pktSizeDistribution"]["size"]

   self:set_label(getHumanReadableInterfaceName(getInterfaceName(ifstats.id)))
   for _, bin in ipairs(available_bins) do
      self:append(bin.label, size_bins[bin.key] or 0)
   end
end

-- #######################################################

-- Checks if this module is being loaded as part of a REST request to this endpoint or not.
-- If the module is being loaded as part of a REST request, then a response is sent, otherwise nothing is done.
-- Must call this to ensure REST responses are sent when necessary
packet_distro:new():rest_send_response()

-- #######################################################

return packet_distro
