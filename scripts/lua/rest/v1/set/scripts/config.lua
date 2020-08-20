--
-- (C) 2019-20 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local info = ntop.getInfo() 

local json = require ("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local user_scripts = require "user_scripts"
local rest_utils = require("rest_utils")
local tracker = require("tracker")

--
-- Import scripts configuration
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

if not haveAdminPrivileges() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

-- ################################################

if(_POST["JSON"] == nil) then
  rest_utils.answer(rest_utils.consts.err.invalid_args)
  return
end

local data = json.decode(_POST["JSON"])

if(table.empty(data)) then
  rest_utils.answer(rest_utils.consts.err.bad_format)
  return
end

if data["0"] == nil then
  rest_utils.answer(rest_utils.consts.err.bad_content)
  return
end

-- ################################################

local failure = false

for config_id, configset in pairs(data) do
  if configset.name ~= nil then
    local success, err = user_scripts.createOrReplaceConfigset(configset)
    if not success then
      failure = true
    end
  end
end

if failure then
  rest_utils.answer(rest_utils.consts.err.internal_error)
  return
end

-- ################################################

-- TRACKER HOOK
tracker.log('set_scripts_config', {})

rest_utils.answer(rest_utils.consts.success.ok)
