--
-- (C) 2021 - ntop.org
--

-- Import the classes library.
local classes = require "classes"

-- ##############################################

local datamodel = classes.class()

-- ##############################################

local datamodel_colors = {
   'rgba(255, 127, 14, 1)',
   'rgba(174, 199, 232, 1)',
   'rgba(255, 187, 120, 1)',
   'rgba(31, 119, 180, 1)',
   'rgba(255, 99, 132, 1)',
   'rgba(54, 162, 235, 1)',
   'rgba(255, 206, 86, 1)',
   'rgba(75, 192, 192, 1)',
   'rgba(153, 102, 255, 1)',
   'rgba(255, 159, 64, 1)'
}

-- ######################################

function datamodel:init(labels)
   self.column_labels = labels
   self.datasets      = {} -- Possibly legacy, to be removed
   self._data         = {} -- New data container
end

-- ######################################

function datamodel:appendRow(when, dataset_name, row)
   if(self.datasets[dataset_name] == nil) then
      self.datasets[dataset_name] = {}

      self.datasets[dataset_name].rows       = {}
      self.datasets[dataset_name].timestamps = {}
   end

   table.insert(self.datasets[dataset_name].timestamps, when)
   table.insert(self.datasets[dataset_name].rows, row)

end

-- ######################################

-- Return the data formatted as expected by a table widget
function datamodel:getAsTable()
   local ret = {}
   local dataset_name

   -- take the first dataset
   for k,v in pairs(self.datasets) do
      dataset_name = k
   end

   ret.header = self.column_labels

   if(dataset_name == nil) then
      ret.rows = {}
   else
      ret.rows = self.datasets[dataset_name].rows
   end

   return(ret)
end

-- ######################################

-- Return the data formatted as expected by a donut chart
function datamodel:getAsDonut()
   local ret = { data = {}}

   for k,v in pairs(self.datasets) do
      local i = 1

      for k1,v1 in pairs(v.rows) do
	 for k2,v2 in pairs(v1) do
	    table.insert(ret.data, { label = self.column_labels[i], value = v2 })
	    i = i + 1
	 end

	 ret.title = k
	 break 	 -- We expect only one entry
      end

   end

   return(ret)
end

-- ######################################

-- Return the data formatted as expected by a multibar chart
function datamodel:getAsMultibar()
   local ret = { }
   local i = 0

   for k,v in pairs(self.datasets) do
      local serie = { values = {} }
      local label = self.column_labels[i+1]

      for k1,v1 in pairs(v.rows) do
	      table.insert(serie.values, { x = v.timestamps[k1], y = v1, series = i, y0 = 0, y1 = v1, key = label })
      end

      serie.key = label
      serie.nonStackable = false

      table.insert(ret, serie)
      i = i + 1
   end

   return(ret)
end

-- ######################################

-- Return the data
-- NOTE: Legacy, use get_data instead
function datamodel:getData(transformation, dataset_name)
   transformation = string.lower(transformation)
   
   if(transformation == "table") then
      return(self:getAsTable())
   elseif(transformation == "donut") then
      return(self:getAsDonut())
   elseif(transformation == "multibar") then
      return(self:getAsMultibar())
   else
      return({})
   end
end

-- ######################################

-- @brief append data to the model.
-- @param data_key The key identifying the data, i.e., a timestamp (for timeseries) or a string (for histograms)
-- @param data_values The value or values associated to the data key. Can be a salar or an array.
function datamodel:append(data_key, data_values)
   -- Always append ordered data
   self._data[#self._data + 1] = {
      k = data_key, -- The Key
      v = data_values -- The Values
   }
end

-- ######################################

-- @brief Returns datamodel data as-is, without any transformation
function datamodel:get_data()
   return self._data
end

-- ######################################

return(datamodel)
