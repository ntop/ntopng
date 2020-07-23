--
-- (C) 2014-20 - ntop.org
--

local lua_path_utils = {}

-- ########################################################

function lua_path_utils.package_path_preprend(path)
   local include_path = path.."/?.lua;"

   if not package.path:match(include_path) then
      package.path = include_path..package.path
   end
end

-- ########################################################

return lua_path_utils

