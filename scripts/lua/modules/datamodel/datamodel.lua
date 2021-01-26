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
end

-- ######################################

-- @brief append data to the model.
function datamodel:append()
   -- Must be implemented in subclasses
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

-- Transform and return datamodel data
function datamodel:transform(transformation)
   -- Data is possibly transformed in subclasses
   return self:get_data()
end

-- ######################################

return(datamodel)
