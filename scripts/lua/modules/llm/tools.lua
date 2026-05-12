--
-- (C) 2013-26 - ntop.org
--

-- Base tool registry for the agentic LLM loop.
-- Always loaded by mcp.lua. Contains tools that work with live ntopng data only
-- Pro tools are loaded on top if nAnalyst is available

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/llm/tools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require("dkjson")

local tools = {}

-- name -> { description, handler, artifact, read_only }
tools._registry = {}

function tools.register(name, description, handler, opts)
   tools._registry[name] = {
      description = description,
      handler     = handler,
      artifact    = (opts and opts.artifact == true) or false,
      read_only   = (opts and opts.read_only == true) or false,
   }
end

function tools.dispatch(action, content)
   local tool = tools._registry[action]
   if not tool then
      return nil, "unknown tool: " .. tostring(action), nil
   end

   if type(content) == "string" and content:match("^%s*[%[{]") then
      local decoded = json.decode(content)
      if decoded ~= nil then content = decoded end
   end

   local ok, result, err, artifact = pcall(tool.handler, content)
   if not ok then
      return nil, "tool '" .. action .. "' threw: " .. tostring(result), nil
   end
   return result, err, artifact
end

function tools.hint_block()
   local lines = { "AVAILABLE TOOLS" }
   local names = {}
   for name in pairs(tools._registry) do names[#names + 1] = name end
   table.sort(names)
   for _, name in ipairs(names) do
      lines[#lines + 1] = "  " .. name .. " — " .. tools._registry[name].description
   end
   return table.concat(lines, "\n")
end

----------------------------------------------------------------------------------------
-- Load tools from tools/ directory

local function load_tools_from_directory(tool_dir)
   local tools_path = dirs.installdir .. "/scripts/lua/modules/llm/" .. tool_dir .. "/"
   local cmd = "find '" .. tools_path .. "' -maxdepth 1 -name '*.lua' -type f"

   local handle = io.popen(cmd)
   if not handle then
      tprint("[tools] warning: unable to scan directory " .. tool_dir)
      return
   end

   for file_path in handle:lines() do
      local file = file_path:match("([^/]+)%.lua$")
      if file then
         local ok, tool_def = pcall(function()
            return require(file)
         end)

         if ok and type(tool_def) == "table" and tool_def.name and tool_def.handler then
            tools.register(tool_def.name, tool_def.description or "", tool_def.handler, tool_def.opts or {})
            tprint("[tools] loaded: " .. tool_def.name)
         else
            if not ok then
               tprint("[tools] warning: failed to load tool " .. file .. ": " .. tostring(tool_def))
            end
         end
      end
   end
   handle:close()
end

load_tools_from_directory("tools")

do
   local names = {}
   for n in pairs(tools._registry) do names[#names + 1] = n end
   table.sort(names)
end

return tools
