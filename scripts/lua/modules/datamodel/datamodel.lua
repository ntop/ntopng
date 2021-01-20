--
-- (C) 2021 - ntop.org
--

-- Import the classes library.
local classes = require "classes"
-- Import some colors for eyecandy
local colors = require "graph_utils".graph_colors

-- ##############################################

local datamodel = classes.class()

-- ##############################################

function datamodel:init(labels)
   self.column_labels = labels
   self._data             = {} -- Data container (legacy, to be removed)
end

-- ######################################

-- @brief append data to the model.
-- @param data_key The key identifying the data, i.e., a timestamp (for timeseries) or a string (for histograms)
-- @param data_values The value or values associated to the data key. Can be a salar or an array.
-- @param data_url A URL associated to this data identified with `data_key` (optional)
-- @param data_color A color associated to this data identified with `data_color` (optional)
function datamodel:append(data_key, data_values, data_url, data_color)
   tprint(colors)
   -- Always append ordered data
   self._data[#self._data + 1] = {
      k = data_key,       -- The Key
      v = data_values,    -- The Values
      url = data_url,
      color = colors[(#self._data - 1) % #colors],
   }
end

-- ######################################

-- @brief Data consolidation to be called after `append`ing data
function datamodel:aggregate()
   -- Possibly implemented in subclasses
end

-- ######################################

-- @brief Returns datamodel data as-is, without any transformation
function datamodel:get_data()
   return self._data
end

-- ######################################

function datamodel:get_data_keys()
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data.k
   end

   return res
end

-- ######################################

function datamodel:get_data_values()
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data.v
   end

   return res
end

-- ######################################

function datamodel:get_data_colors()
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data.color
   end

   return res
end

-- ######################################

-- Transform and return datamodel data
function datamodel:transform(transformation)
   if transformation == "aggregate" then
      -- Transform, enforce maximum number of results, % returned
      self:aggregate()
   else -- transformation == "none", i.e., all data is returned, no filtering, no reduction

   end

   return {
      label  = self.column_labels,
      keys   = self:get_data_keys(),
      values = self:get_data_values(),
      colors = self:get_data_colors()
   }
end

-- ######################################

return(datamodel)
