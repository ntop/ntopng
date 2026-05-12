--
-- (C) 2013-26 - ntop.org
--
-- MCP (Model Context Protocol) server for ntopng LLM tools.
-- Transport : MCP 2025-03-26 Streamable HTTP
-- Auth      : HTTP Basic Auth  "Authorization: Basic base64(user:pass)"
--             HTTP Token Auth  "Authorization: Token <api-token>"

--
-- POST /lua/rest/v2/exec/llm/mcp.lua          (JSON-RPC 2.0 body)
-- GET  /lua/rest/v2/exec/llm/mcp.lua          (server health / discovery)
-- Optional query param: ?ifid=<interface_id>   (default: 0)

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;"         .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;"     .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/llm/?.lua;" .. package.path

local json        = require("dkjson")
local rest_utils  = require("rest_utils")
local page_utils  = require("page_utils")

-- Helpers
local function send_json(body, status_code)
   rest_utils.sendHTTPContentTypeHeader("application/json", nil, nil, nil, status_code)
   if body and body ~= "" then print(body) end
end

local function rpc_ok(id, result)
   return json.encode({ jsonrpc = "2.0", id = id, result = result })
end

local function rpc_err(id, code, message)
   return json.encode({ jsonrpc = "2.0", id = id,
      error = { code = code, message = message } })
end

-- Authentication Checks
local current_user = (_SESSION and _SESSION["user"]) or ""
if current_user == "" then
   send_json(rpc_err(nil, -32001, "Unauthorized: valid credentials required"), 401)
   return
end

if not isAdministrator() then
   send_json(rpc_err(nil, -32003, "Forbidden: administrator role required"), 403)
   return
end


-- Load LLM tools, start by loading community tools, if nAnalyst is available load pro tools
local _tools_mod = nil

local function get_tools()
   if _tools_mod then return _tools_mod, nil end
   
   -- httplint does not parse jsonrpc format yet
   ignore_post_payload_parse = true  -- luacheck: ignore
   pragma_once_http_lint      = true  -- luacheck: ignore

   -- Community tools: scripts/lua/modules/llm/tools.lua
   package.path = dirs.installdir .. "/scripts/lua/modules/llm/?.lua;" .. package.path
   local ok, mod = pcall(function() return require("tools") end)
   if not ok then
      return nil, "ntopng LLM tools not available: " .. tostring(mod)
   end

   -- nAnalyst tools: pro/scripts/lua/modules/llm/pro_tools.lua
   if page_utils.has_nanalyst() then
      local ok2, err2 = pcall(function() return require("pro_tools") end)
      if not ok2 then
         tprint("[mcp] pro_tools load failed (using community tools): " .. tostring(err2))
      end
   end

   _tools_mod = mod
   return mod, nil
end

-- MCP initialize
local _system_prompt = nil

local function get_system_prompt()
   if _system_prompt then return _system_prompt end
   local ok, prompts = pcall(function() return require("prompts") end)
   if ok and prompts and prompts.system_prompt then
      _system_prompt = prompts.system_prompt(false)
   else
      _system_prompt = "You are connected to an ntopng network monitoring instance. "
         .. "Use the available tools to query network traffic, flows, alerts, assets, "
         .. "SNMP devices, and manage active monitoring and AI policies."
   end
   return _system_prompt
end

local function handle_initialize(id, _params)
   return rpc_ok(id, {
      protocolVersion = "2025-03-26",
      capabilities    = { tools = { listChanged = false } },
      serverInfo      = { name = "ntopng-mcp", version = "1.0" },
      instructions    = get_system_prompt(),
   })
end

-- MCP method: tools/list -> Exposes every entry in tools._registry as an MCP tool.
local function handle_tools_list(id, _params)
   local tools, err = get_tools()
   if not tools then return rpc_err(id, -32603, err) end

   local list = {}
   for name, entry in pairs(tools._registry) do
      list[#list + 1] = {
         name        = name,
         description = entry.description,
         inputSchema = {
            type       = "object",
            properties = {
               content = {
                  type        = "string",
                  description = "Tool input. "
                     .. "For 'query': a plain SQL string. "
                     .. "For all other tools: a JSON object encoded as a string "
                     .. "(e.g. '{\"ip\":\"192.168.1.1\"}').",
               },
            },
            required = { "content" },
         },
         annotations = {
            readOnlyHint    = (entry.read_only == true),
            destructiveHint = false,
         },
      }
   end

   table.sort(list, function(a, b) return a.name < b.name end)
   return rpc_ok(id, { tools = list })
end

-- MCP method: tools/call -> Dispatches to tools.dispatch(name, content).
local function handle_tools_call(id, params)
   if type(params) ~= "table" then
      return rpc_err(id, -32602, "params must be an object")
   end

   local tool_name = params.name
   local arguments = params.arguments or {}

   if type(tool_name) ~= "string" or tool_name == "" then
      return rpc_err(id, -32602, "params.name is required")
   end

   local tools, err = get_tools()
   if not tools then return rpc_err(id, -32603, err) end

   -- Derive content from arguments:
   --   {content: "..."}   -> pass content value directly (like agentic loop)
   --   {sql: "..."}       -> shorthand for query tool
   --   {any other keys}   -> JSON-encode and pass as content (dispatch decodes it)
   --   {}                 -> empty string
   local content

   if arguments.content ~= nil then
      content = arguments.content
   elseif arguments.sql ~= nil then
      -- Convenience: {sql: "SELECT ..."} for the query tool
      content = arguments.sql
   elseif next(arguments) ~= nil then
      content = json.encode(arguments)
   else
      content = ""
   end

   -- call tool
   local result, tool_err, artifact = tools.dispatch(tool_name, content)

   if tool_err and not result then
      return rpc_err(id, -32603, "tool error: " .. tostring(tool_err))
   end

   local text = result or ""
   if tool_err then
      text = text .. "\n[tool warning: " .. tostring(tool_err) .. "]"
   end

   local mcp_content = { { type = "text", text = text } }

   -- Artifact such as chart. Embed it as a tagged text block so MCP clients can parse it if desired.
   if artifact then
      mcp_content[#mcp_content + 1] = {
         type = "text",
         text = "NTOPNG_ARTIFACT:" .. json.encode(artifact),
      }
   end

   return rpc_ok(id, {
      content = mcp_content,
      isError = (tool_err ~= nil and result == nil),
   })
end

-- JSON-RPC 2.0 dispatcher
local method_handlers = {
   ["initialize"]               = handle_initialize,
   ["tools/list"]               = handle_tools_list,
   ["tools/call"]               = handle_tools_call,
   ["ping"]                     = function(id, _) return rpc_ok(id, {}) end,
   
   -- Notifications: no id, no response expected
   ["notifications/initialized"] = function(_, _) return nil end,
   ["notifications/cancelled"]   = function(_, _) return nil end,
}

local function dispatch_request(req)
   if type(req) ~= "table" then
      return rpc_err(nil, -32600, "invalid request")
   end

   local req_id     = req.id
   local method = req.method
   local params = req.params

   local handler = method_handlers[method]
   if handler then
      return handler(req_id, params)
   end

   -- Unknown method: only respond if there is an id, not a notification
   if req_id ~= nil then
      return rpc_err(req_id, -32601, "method not found: " .. tostring(method))
   end
   return nil
end

-------------------------------------------------------------------
-- Entry point
local http_method = (_SERVER and _SERVER["REQUEST_METHOD"]) or "GET"

-- GET -> health / discovery 
if http_method == "GET" then
   local tools, _ = get_tools()
   local tool_count = 0

   if tools then
      for _ in pairs(tools._registry) do tool_count = tool_count + 1 end
   end

   send_json(json.encode({
      server          = "ntopng-mcp",
      protocol        = "2025-03-26",
      authenticated_as = current_user,
      tools_available = tool_count,
   }))
   return
end

-- POST -> JSON-RPC 2.0
local payload = _POST and _POST["payload"]
if not payload or payload == "" then
   send_json(rpc_err(nil, -32700, "empty request body; "
      .. "POST Content-Type must be application/json"), 400)
   return
end

local request, _, parse_err = json.decode(payload)
if request == nil then
   send_json(rpc_err(nil, -32700, "JSON parse error: " .. tostring(parse_err)), 400)
   return
end

-- Batch request: array of JSON-RPC objects
if type(request) == "table" and request[1] ~= nil then
   local responses = {}

   for _, req in ipairs(request) do
      local resp_str = dispatch_request(req)
      if resp_str then
         local obj = json.decode(resp_str)
         if obj then responses[#responses + 1] = obj end
      end
   end
   
   -- If all were notifications there is nothing to return
   send_json(#responses > 0 and json.encode(responses) or "")
   return
end

local resp_str = dispatch_request(request)
if not resp_str then
   rest_utils.sendHTTPContentTypeHeader("application/json", nil, nil, nil, 202)
else
   send_json(resp_str)
end
