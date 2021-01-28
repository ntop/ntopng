--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datamodel/?.lua;" .. package.path

-- ##############################################

-- Import the classes library.
local classes = require "classes"
-- Import the base class
local datamodel = require "datamodel"
-- Import some colors for eyecandy
local colors = require "graph_utils".graph_colors

-- ##############################################

local heatmap = classes.class(datamodel)

-- ##############################################

heatmap.meta = {
   -- Default values
}

-- ##############################################

-- @brief Datasource constructor
function heatmap:init(labels)
   -- Call the parent constructor
   self.super:init(labels)
end

-- #######################################################

-- @brief append data to the model.
-- @param data_x The key identifying the first data dimension
-- @param data_y The key identifying the second data dimension
-- @param data_v The value or values associated to the data keys `data_x` and `data_y`. Can be a salar or an array.
-- @param data_l The label associated to this data (optional)
-- @param data_url A URL associated to this data (optional)
-- @param data_color A color associated to this data (optional)
--        OVERRIDE
function heatmap:append(data_x, data_y, data_v, data_l, data_url, data_color)
   -- Always append ordered data
   self._data[#self._data + 1] = {
      x = data_x,
      y = data_y,
      v = data_v,
      l = data_l,
      url = data_url,
      color = data_color or colors[#self._data % #colors],
   }
end

-- #######################################################

function heatmap:_get_data_dimension(dimension)
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data[dimension]
   end

   return res
end

-- #######################################################

-- Transform and return datamodel data
function heatmap:transform(transformation)
   -- No transformation yet

   return {
      label  = self.column_labels,
      x      = self:_get_data_dimension("x"),
      y      = self:_get_data_dimension("y"),
      labels = self:_get_data_dimension("l"),
      values = self:_get_data_dimension("v"),
      colors = self:_get_data_dimension("color"),
   }
end

-- #######################################################

return heatmap
