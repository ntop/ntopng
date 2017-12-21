--
-- (C) 2014-17 - ntop.org
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
   if(ntop.isWindows() and (string.len(path) > 2)) then
      path = string.gsub(path, "/", os_utils.getPathDivider())
   end

  return(path)
end

-- #################################

return os_utils

