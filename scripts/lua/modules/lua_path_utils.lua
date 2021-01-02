--
-- (C) 2014-21 - ntop.org
--

local lua_path_utils = {}

-- ########################################################

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start)) == Start
end

-- ########################################################

function lua_path_utils.package_path_prepend(path)
   local include_path = path.."/?.lua;"

   -- If the path is already inside package.path, we remove it, before prepending it
   if not string.starts(package.path, include_path) and package.path:gmatch(include_path) then
      package.path = package.path:gsub(include_path, '')
   end

   package.path = include_path..package.path
end

-- ########################################################

return lua_path_utils

