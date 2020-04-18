--
-- (C) 2020 - ntop.org
--

local datamodel = {}
datamodel.__index = datamodel

-- ######################################

function datamodel:create(labels)
   local ret = {}

   setmetatable(ret,datamodel)  -- Create the class
   
   ret.column_labels = labels
   ret.rows          = {}
   ret.timestamps    = {}

   return(ret)
end

-- ######################################

function datamodel:appendRow(when, row)
   table.insert(self.timestamps, when)
   table.insert(self.rows, row)
end

-- ######################################

-- Return the data formatted as expected by a table widget
function datamodel:getAsTable()
   local ret = {}

   ret.header = self.column_labels
   ret.rows   = self.rows
   
   return(ret)
end

-- ######################################

-- Return the data
function datamodel:getData(transformation)
   if(transformation == "table") then
      return(self:getAsTable())
   else
      return({})
   end
end

-- ######################################

return(datamodel)
