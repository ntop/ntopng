--
-- (C) 2016-18 - ntop.org
--

--
-- This is the user scripts loader. It exposes to the C side the callbacks from
-- the user scripts.
--

local dirs = ntop.getDirs()
local scripts_dir = dirs.installdir .. "/scripts/callbacks/user_scripts/"..script_context

local scripts_callbacks = {}

if ntop.isdir(scripts_dir) then
  package.path = scripts_dir.."/?.lua;" .. package.path

  for _,script in pairs(ntop.readdir(scripts_dir)) do
    if (script ~= nil) then
      local module_name = script:match("([^.]+).lua")
      if module_name ~= nil then
        local module_callbacks = require(module_name)

        for callback_name, callback in pairs(module_callbacks) do
          if _G[callback_name] == nil then

            -- Define the global hook called by the C side
            _G[callback_name] = function (...)
              -- Note: order is not currently preserved
              for _, callback in pairs(scripts_callbacks[callback_name]) do
                callback(table.unpack(arg or {}))
              end
            end

            scripts_callbacks[callback_name] = {}
          end

          -- Add the callback to be called
          scripts_callbacks[callback_name][#scripts_callbacks[callback_name] + 1] = callback
        end
      end
    end
  end
end

