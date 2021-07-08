--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/datamodel/?.lua;" .. package.path

-- ##############################################

-- Import the classes library.
local classes = require "classes"
-- Import some colors for eyecandy
local colors = require "graph_utils".graph_colors
local rest_utils = require "rest_utils"

-- ##############################################

local slices = classes.class()

-- ##############################################

-- This is the base REST prefix for all the available datasources
slices.BASE_REST_PREFIX = "/lua/rest/v2/get/datasource/"

-- ##############################################

-- Default values
local default_max_num_slices      = 10 -- Maximum number of slices handled
local default_other_threshold_pct = 3  -- Percentage under which the slice is ignored and value added to a slice 'other'

-- ##############################################

-- @brief Datasource constructor
function slices:init(max_num_slices, other_threshold_pct)
   self.max_num_slices = max_num_slices or default_max_num_slices
   self.other_threshold_pct = other_threshold_pct or default_other_threshold_pct

   self.column_labels = labels
   self._data = {}
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
      color = colors[(#self._data % #colors) + 1],
   }
end

-- #######################################################

-- @brief Aggregates `append`ed data, enforcing `max_num_slices` and `other_threshold_pct`
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

      if cur_slice < self.max_num_slices and slice.v / total_value * 100 > self.other_threshold_pct then
	 -- Preserve this slice
	 aggregated[#aggregated + 1] = slice
      elseif slice.v > 0 then
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
-- @brief Transform data according to the specified transformation
-- @param transformation The transformation to be applied
-- @return transformed data
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

-- ##############################################

function slices:set_label(label)
   self.column_labels = label
end

-- ##############################################

-- ##############################################

-- @brief Parses params
-- @param params_table A table with submitted params
-- @return True if parameters parsing is successful, false otherwise
function slices:read_params(params_table)
   if not params_table then
      self.parsed_params = nil
      return false
   end

   self.parsed_params = {}
   for _, param in pairs(self.meta.params or {}) do
      local parsed_param = params_table[param]

      -- Assumes all params mandatory and not empty
      -- May override this behavior in subclasses
      if isEmptyString(parsed_param) then
	 -- Reset any possibly set param
	 self.parsed_params = nil

	 return false
      end

      self.parsed_params[param] = parsed_param
   end

   -- Ok, parsin has been successful
   return true
end

-- ##############################################

-- @brief Parses params submitted along with the REST endpoint request. If parsing fails, a REST error is sent.
-- @param params_table A table with submitted params, either _POST or _GET
-- @return True if parameters parsing is successful, false otherwise
function slices:_rest_read_params(params_table)
   if not self:read_params(params_table) then
      rest_utils.answer(rest_utils.consts.err.widgets_missing_datasource_params)
      return false
   end

   return true
end

-- ##############################################

-- @brief Send slices data via REST
function slices:rest_send_response()
   -- Make sure this is a direct REST request and not just a require() that needs this class
   if not _SERVER -- Not executing a Lua script initiated from the web server (i.e., backend execution)
   or not _SERVER["URI"] -- Cannot reliably determine if this is a REST request
   or not _SERVER["URI"]:starts(slices.BASE_REST_PREFIX) -- Web Lua script execution but not for this REST endpoint
   then
      -- Don't send any REST response
      return
   end

   if not self:_rest_read_params(_POST) then
      -- Params parsing has failed, error response already sent by the caller
      return
   end

   self:fetch()

   rest_utils.answer(
      rest_utils.consts.success.ok,
      self._data
   )
end

-- ##############################################

-- @brief Returns instance metadata, which depends on the current instance and parsed_params
function slices:get_metadata()
   local res = {}

   -- Render a url with submitted parsed_params
   -- TODO: add url if necessary

   return res
end

-- #######################################################

return slices
