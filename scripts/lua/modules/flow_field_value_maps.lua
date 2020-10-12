--
-- (C) 2014-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/flow_field_value_maps/?.lua;" .. package.path

local os_utils = require "os_utils"
local json = require "dkjson"

local flow_field_value_maps = {}

local pen_map = {}

local pen_to_map_file = {
   ["8741"] = "sonicwall_app_id"
}

-- ################################################################################

local function init_flow_field_value_map(field_pen)
   if pen_to_map_file[field_pen] and not pen_map[field_pen] then
      pen_map[field_pen] = require(pen_to_map_file[field_pen])
   end
end

-- ################################################################################

function flow_field_value_maps.key_to_pen_type_and_value(field)
   -- nProbe exports the field as the dot-concatenation
   -- of PEN and TYPE
   -- Example: 8741.22
   -- 8741 is the PEN of Sonicwall
   -- 22 is the TYPE 22 with pen Sonicwall

   local pen_type = field:split("%.") or {}

   --   tprint({field = field, field_pen = field_pen, field_type = field_type})
   return pen_type[1], pen_type[2], pen_type[3]
end

-- ################################################################################

function flow_field_value_maps.options_topic_field_value_map(ifid, pen, field, value)
   -- check the hash cache set when nProbe tells us the mappings over the options topic
   local k = string.format("ntopng.cache.ifid_%u.field_value_map.pen_%u.field_%u", ifid, pen, field)
   local res = ntop.getHashCache(k, value)

   local jres = json.decode(res)
   if jres and jres["name"] then
      return jres["name"]
   end

   return value
end

-- ################################################################################

function flow_field_value_maps.map_field_value(ifid, field, value)
   local field_pen, field_type = flow_field_value_maps.key_to_pen_type_and_value(field)

   if field_pen ~= nil and field_type ~= nil then
      -- if pen or type is nil then
      -- it has not been possible to extract pen and type (string field?)
      -- so no mapping can be found for this value

      -- lazy init of the mapping
      init_flow_field_value_map(field_pen)

      -- do the actual mapping
      if pen_map[field_pen] then
	 field, value = pen_map[field_pen].map_field_value(ifid, field_type, value)
      elseif rtemplate[tonumber(field_type)] then
	 -- If there's no match on pen_map, attempt at decoding using the nProbe rtemplate
	 -- NOTE: see function getFlowKey in flow_utils.lua
	 field = rtemplate[tonumber(field_type)]
      end

      -- override with static mappings with those received from nProbe on the options topic
      value = flow_field_value_maps.options_topic_field_value_map(ifid, field_pen, field_type, value)
   end

   return field, value
end

-- ################################################################################

return flow_field_value_maps
