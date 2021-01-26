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

local slices = classes.class(datamodel)

-- ##############################################

slices.meta = {
   -- Default values
   max_num_slices      = 10, -- Maximum number of slices handled
   other_threshold_pct = 3,  -- Percentage under which the slice is ignored and value added to a slice 'other'
}

-- ##############################################

-- @brief Datasource constructor
function slices:init(labels, max_num_slices, other_threshold_pct)
   -- Call the parent constructor
   self.super:init(labels)

   if max_num_slices then
      self.meta.max_num_slices = max_num_slices
   end

   if other_threshold_pct then
      self.meta.other_threshold_pct = other_threshold_pct
   end
end

-- #######################################################

-- @brief append data to the model.
-- @param data_key The key identifying the data, i.e., a timestamp (for timeseries) or a string (for histograms)
-- @param data_values The value or values associated to the data key. Can be a salar or an array.
-- @param data_url A URL associated to this data identified with `data_key` (optional)
-- @param data_color A color associated to this data identified with `data_color` (optional)
--        OVERRIDE
function slices:append(data_key, data_values, data_url, data_color)
   -- Always append ordered data
   self._data[#self._data + 1] = {
      k = data_key,       -- The Key
      v = data_values,    -- The Values
      url = data_url,
      color = colors[#self._data % #colors],
   }
end

-- #######################################################

-- @brief Aggregates `append`ed data, enforcing `max_num_slices` and `other_threshold_pct`
--        OVERRIDE
function slices:aggregate()
   local aggregated = {}
   local other
   local total_value = 0
   local cur_slice = 1

   -- Compute the total
   for _, slice in ipairs(self._data) do
      total_value = total_value + slice.v
   end

   -- Sort by descending `v`alue of slice
   for _, slice in ipairs(self._data) do
      local slice_key = slice.k

      if cur_slice < self.meta.max_num_slices and slice.v / total_value * 100 > self.meta.other_threshold_pct then
	 -- Preserve this slice
	 aggregated[#aggregated + 1] = slice
      else
	 -- Start adding to the 'other' slice
	 if not other then
	    other = slice
	    other.k = 'other'
	 else
	    -- Sum the current `other` value with the value for this slice
	    other.v = other.v + slice.v
	 end
      end

      cur_slice = cur_slice + 1
   end

   if other then
      aggregated[#aggregated + 1] = other
   end

   self._data = aggregated
end

-- #######################################################

function slices:_get_data_keys()
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data.k
   end

   return res
end

-- #######################################################

function slices:_get_data_values()
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data.v
   end

   return res
end

-- #######################################################

function slices:_get_data_colors()
   local res = {}

   for _, data in ipairs(self._data) do
      res[#res + 1] = data.color
   end

   return res
end

-- #######################################################

-- Transform and return datamodel data
function slices:transform(transformation)
   if transformation == "aggregate" then
      -- Transform, enforce maximum number of results, % returned
      self:aggregate()
   else -- transformation == "none", i.e., all data is returned, no filtering, no reduction

   end

   return {
      label  = self.column_labels,
      keys   = self:_get_data_keys(),
      values = self:_get_data_values(),
      colors = self:_get_data_colors()
   }
end

-- #######################################################

return slices
