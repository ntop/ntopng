local template = require "resty.template"
local os_utils = require "os_utils"

-- This can be used inside templates
-- range(a) returns an iterator from 1 to a (step = 1)
-- range(a, b) returns an iterator from a to b (step = 1)
-- range(a, b, step) returns an iterator from a to b, counting by step.
function range(a, b, step)
  if not b then
    b = a
    a = 1
  end
  step = step or 1
  local f =
    step > 0 and
      function(_, lastvalue)
        local nextvalue = lastvalue + step
        if nextvalue <= b then return nextvalue end
      end or
    step < 0 and
      function(_, lastvalue)
        local nextvalue = lastvalue + step
        if nextvalue >= b then return nextvalue end
      end or
      function(_, lastvalue) return lastvalue end
  return f, nil, a - step
end

function template.gen(template_file, context, is_full_path)
  local path

  if is_full_path then
     path = os_utils.fixPath(template_file)
  else
     path = os_utils.fixPath(dirs.installdir.."/httpdocs/templates/"..template_file)

     if not ntop.exists(path) and ntop.isPro() then
	-- Try in the pro dir
	path = os_utils.fixPath(dirs.installdir.."/pro/httpdocs/templates/"..template_file)
     end
  end

  return template.compile(path, nil, nil)(context)
end

---Print the template inside the requested page
---@param template_file string The template file to render
---@param context table The data used by the page template
---@param is_full_path boolean Is an absolute path?
function template.render(template_file, context, is_full_path)
  print(template.gen(template_file, context, is_full_path))
end

return template
