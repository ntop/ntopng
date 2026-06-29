--
-- (C) 2014-26 - ntop.org
--
-- GET /lua/rest/v2/get/ntopng/test_llm_connectivity.lua
--
-- Tests an LLM API endpoint by POSTing a minimal chat completion request.
-- Query params:
--   url       - full chat completions endpoint URL (required)
--   llm_token - bearer / API key (optional)
--   model     - model name (optional)
--   llm_key   - entry key name, used to detect provider (e.g. "anthropic_url")
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local rest_utils = require "rest_utils"
local auth       = require "auth"
local json       = require "dkjson"

if not auth.has_capability(auth.capabilities.preferences) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local url   = _GET["url"]       or ""
local token = _GET["llm_token"] or ""
local model = _GET["model"]     or ""
local key   = _GET["llm_key"]   or ""

if isEmptyString(url) then
   rest_utils.answer(rest_utils.consts.err.invalid_args, { message = "URL is required" })
   return
end

-- Infer provider from the entry key (e.g. "anthropic_url" → Anthropic auth headers)
local is_anthropic = (key:find("anthropic") ~= nil)

local payload = json.encode({
   model      = (not isEmptyString(model)) and model or "gpt-4o-mini",
   stream     = false,
   max_tokens = 1,
   messages   = {{ role = "user", content = "ping" }},
})

local rc = ntop.httpPost(url, payload, {
   timeout        = 10,
   return_content = true,
   bearer         = (not is_anthropic and not isEmptyString(token)) and token or nil,
   x_api_key      = (is_anthropic     and not isEmptyString(token)) and token or nil,
   extra_header   = is_anthropic and "anthropic-version: 2023-06-01" or nil,
})

local response_code = nil
local body = ""

if type(rc) == "table" then
   response_code = rc.RESPONSE_CODE
   body = rc.CONTENT or ""
elseif type(rc) == "string" then
   body = rc
end

local response = nil
if not isEmptyString(body) then
   response = json.decode(body)
end

if response_code == 401 or response_code == 403 then
   local msg = "Authentication failed"
   if type(response) == "table" then
      if type(response.error) == "table" then
         msg = response.error.message or msg
      elseif type(response.error) == "string" then
         msg = response.error
      end
   end
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = msg })
   return
end

if response_code == 404 then
   rest_utils.answer(rest_utils.consts.err.bad_content, { message = "Endpoint not found — check the URL" })
   return
end

-- Any 2xx/4xx except 401/403/404 means the API is reachable
if response_code and response_code >= 200 and response_code < 500 then
   rest_utils.answer(rest_utils.consts.success.ok, { message = "API endpoint reachable" })
   return
end

rest_utils.answer(rest_utils.consts.err.bad_content, {
   message = "Server error (HTTP " .. tostring(response_code or "no response") .. ")"
})
