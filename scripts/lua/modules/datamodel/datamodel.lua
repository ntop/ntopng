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
   self._data         = {} -- Data container
end

-- ######################################

-- @brief append data to the model.
-- @param data_key The key identifying the data, i.e., a timestamp (for timeseries) or a string (for histograms)
-- @param data_values The value or values associated to the data key. Can be a salar or an array.
-- @param data_url A URL associated to this data identified with `data_key` (optional)
-- @param data_color A color associated to this data identified with `data_color` (optional)
function datamodel:append(data_key, data_values, data_url, data_color)
   -- Always append ordered data
   self._data[data_key] = {
      k = data_key,       -- The Key
      v = data_values,    -- The Values
      url = data_url,
      color = data_color,
   }
end

-- ######################################

-- @brief Data consolidation to be called after `append`ing data
function datamodel:consolidate()
   -- Possibly implemented in subclasses
end

-- ######################################

-- @brief Returns datamodel data as-is, without any transformation
function datamodel:get_data()
   local res = {}

   for k, v in pairsByKeys(self._data) do
      res[#res + 1] = v
   end

   return res
end

-- ######################################

-- Transform and return datamodel data
function datamodel:transform(transformation)
   -- TODO: implement transformations
   if(transformation == "table") then
   elseif(transformation == "donut") then
   elseif(transformation == "multibar") then
   else
   end

   -- TODO: return transformed data
   return self:get_data()
end

-- ######################################

return(datamodel)
