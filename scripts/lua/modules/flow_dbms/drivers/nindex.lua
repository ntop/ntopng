--
-- (C) 2018 - ntop.org
--

local driver = {}
function driver:new(options)
  local obj = {}

  setmetatable(obj, self)
  self.__index = self

  return obj
end

function driver:topk(ifid, what_k, filter)
   local res = {}

   return res
end

return driver
