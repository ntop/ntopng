--
-- (C) 2021 - ntop.org
--

-- Import the classes library.
local classes = require "classes"

-- ##############################################

local datamodel = classes.class()

-- ##############################################

function datamodel:init(labels)
   self.column_labels = labels
   self._data             = {} -- Data container (legacy, to be removed)
   self._dataset_data     = {} -- Per-dataset data
   self._dataset_metadata = {} -- Per-dataset metadata
end

-- ######################################

-- @brief append data to the model.
-- @param data_key The key identifying the data, i.e., a timestamp (for timeseries) or a string (for histograms)
-- @param data_values The value or values associated to the data key. Can be a salar or an array.
-- @param data_url A URL associated to this data identified with `data_key` (optional)
-- @param data_color A color associated to this data identified with `data_color` (optional)
function datamodel:append(data_key, data_values, data_url, data_color)
   -- Always append ordered data
   self._data[#self._data + 1] = {
      k = data_key,       -- The Key
      v = data_values,    -- The Values
      url = data_url,
      color = data_color,
   }
end

-- ######################################

-- @ Brief Add metadata to a dataset identified with `dataset_id`
function datamodel:dataset_metadata(dataset_id, label)
   self._dataset_metadata[dataset_id] = {
      label = label
   } 
end

-- ######################################

-- @brief Append data to the model.
-- @param data_key The key identifying the data, i.e., a timestamp (for timeseries) or a string (for histograms)
-- @param data_values The value or values associated to the data key. Can be a salar or an array.
-- @param data_url A URL associated to this data identified with `data_key` (optional)
-- @param data_color A color associated to this data identified with `data_color` (optional)
function datamodel:dataset_append(dataset_id, data_key, data_values, data_url, data_color)
   if not self._dataset_data[dataset_id] then
      self._dataset_data[dataset_id] = {}
   end

   self._dataset_data[dataset_id][data_key] = {
      k = data_key,       -- The Key
      v = data_values,    -- The Values
      url = data_url,
      color = data_color,
   }
end

-- ######################################

-- @brief Returns datasets data
function datamodel:datasets_get_data()
   local res = {}

   local all_data_keys = {}
   for dataset_id, dataset_data in pairs(self._dataset_data) do
      if not self._dataset_metadata[dataset_id] then
	 -- Add an arbitrary label using the dataset id
	 self._dataset_metadata[dataset_id] = { label = dataset_id }
      end

      for data_key, data in pairs(dataset_data) do
	 tprint(data_key)
      end
   end

   for k, v in pairsByKeys(self._data) do
      res[#res + 1] = v
   end

   return res
end

-- ######################################

-- @brief Data consolidation to be called after `append`ing data
function datamodel:consolidate()
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

-- Transform and return datamodel data
function datamodel:transform(transformation)
   -- TODO: implement transformations
   if transformation == "aggregate" then
      -- Transform, enforce maximum number of results, % returned
   elseif transformation == "none" then
      -- All data is returned, no filtering, no reduction
      return {
	 label  = self.column_labels,
	 keys   = self:get_data_keys(),
	 values = self:get_data_values()
      }
   else
   end

   -- TODO: return transformed data
   return self:get_data()
end

-- ######################################

return(datamodel)
