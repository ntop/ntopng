--
-- (C) 2014-18 - ntop.org
--

local dirs = ntop.getDirs()

local os_utils = {}

-- #################################

function os_utils.getPathDivider()
   if(ntop.isWindows()) then
      return "\\"
   else
      return "/"
   end
end

-- #################################

-- Fix path format Unix <-> Windows
function os_utils.fixPath(path)
   path = string.gsub(path, "//+", '/') -- removes possibly empty parts of the path

   if(ntop.isWindows() and (string.len(path) > 2)) then
      path = string.gsub(path, "/", os_utils.getPathDivider())
   end

  return(path)
end

-- #################################

return os_utils

