--
-- (C) 2020 - ntop.org
--

local datamodel = {}
datamodel.__index = datamodel

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

function datamodel:create(labels)
   local ret = {}

   setmetatable(ret,datamodel)  -- Create the class
   
   ret.column_labels = labels
   ret.datasets      = {}

   return(ret)
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

-- Return the data formatted as expected by a table widget
function datamodel:getAsDoughnut()
   local ret = { data = {}}

   ret.data.labels   = self.column_labels
   ret.data.datasets = {}
   
   for k,v in pairs(self.datasets) do
      local ds = {}

      ds.label = k
      ds.data  = { }
      
      for k1,v1 in pairs(v.rows) do
	 -- We expect only one entry
	 ds.data = v1
      end

      ds.backgroundColor = {}
      ds.borderColor = {}
      
      for a,_ in pairs(ds.data) do
	 local c = datamodel_colors[a]
	 table.insert(ds.backgroundColor, c)
	 table.insert(ds.borderColor, c)
      end
      
      table.insert(ret.data.datasets, ds)
   end

   ret.options = {}
   ret.options.responsive = true
   ret.options.animation = {}
   ret.options.animation.animateScale = true
   ret.options.animation.animateRotate = true
   
   return(ret)
end

-- ######################################

-- Return the data
function datamodel:getData(transformation, dataset_name)
   if(transformation == "table") then
      return(self:getAsTable())
   elseif(transformation == "doughnut") then
      return(self:getAsDoughnut())
   else
      return({})
   end
end

-- ######################################

return(datamodel)
